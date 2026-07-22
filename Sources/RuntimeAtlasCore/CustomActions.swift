import Foundation

public enum CustomActionError: LocalizedError, Equatable, Sendable {
    case invalidName
    case invalidTemplate(String)
    case invalidInput(String)
    case missingValue(String)
    case invalidWorktree(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName: "Command name must be 1-60 characters."
        case .invalidTemplate(let reason): "Command is invalid: \(reason)"
        case .invalidInput(let reason): "Input is invalid: \(reason)"
        case .missingValue(let key): "A value is required for {{\(key)}}."
        case .invalidWorktree(let path): "The selected worktree is not registered: \(path)"
        }
    }
}

public struct CustomActionPlan: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let currentDirectory: String
    public let displayCommand: String
}

public enum CustomActionPlanner {
    public static func validate(_ action: CustomActionDefinition) throws {
        let name = action.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60 else { throw CustomActionError.invalidName }
        let persistedText = [action.name, action.commandTemplate] + action.effects
            + action.inputs.flatMap { [$0.key, $0.label, $0.flagArgument ?? ""] }
        guard !persistedText.contains(where: PrivacySanitizer.containsSensitiveContent) else {
            throw CustomActionError.invalidInput("credentials and URLs must not be stored in a command")
        }
        guard !action.commandTemplate.isEmpty, action.commandTemplate.count <= 500 else {
            throw CustomActionError.invalidTemplate("use 1-500 characters")
        }
        let keys = action.inputs.map(\.key)
        guard Set(keys).count == keys.count else { throw CustomActionError.invalidInput("keys must be unique") }
        for input in action.inputs {
            guard input.key.range(of: #"^[A-Za-z][A-Za-z0-9_]{0,31}$"#, options: .regularExpression) != nil else {
                throw CustomActionError.invalidInput("key '\(input.key)' must use letters, numbers, or underscores")
            }
            let label = input.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty, label.count <= 60 else { throw CustomActionError.invalidInput("labels must be 1-60 characters") }
            if input.kind == .flag {
                guard let flag = input.flagArgument, !flag.isEmpty, flag.count <= 100 else {
                    throw CustomActionError.invalidInput("a checkbox needs an argument such as --delete-branch")
                }
                _ = try tokenize(flag, singleToken: true)
            }
        }
        let tokens = try tokenize(action.commandTemplate)
        guard !tokens.isEmpty else { throw CustomActionError.invalidTemplate("enter an executable") }
        let shells: Set<String> = ["sh", "bash", "dash", "fish", "zsh"]
        for index in tokens.indices.dropLast() {
            let executable = URL(fileURLWithPath: tokens[index]).lastPathComponent.lowercased()
            let option = tokens[index + 1]
            if shells.contains(executable), option.hasPrefix("-"), option.dropFirst().contains("c") {
                throw CustomActionError.invalidTemplate("shell command strings are not supported")
            }
        }
        let known = Set(keys)
        for token in tokens {
            if token.contains("{{") || token.contains("}}") {
                guard token.hasPrefix("{{"), token.hasSuffix("}}"), token.count > 4 else {
                    throw CustomActionError.invalidTemplate("placeholders must be complete arguments such as {{target}}")
                }
                let key = String(token.dropFirst(2).dropLast(2))
                guard known.contains(key) else { throw CustomActionError.invalidTemplate("unknown input {{\(key)}}") }
            }
        }
    }

    public static func plan(
        action: CustomActionDefinition,
        values: [String: String],
        selectedWorktree: String,
        repositoryRoot: String,
        availableWorktrees: [String]
    ) throws -> CustomActionPlan {
        try validate(action)
        let allowed = Set(availableWorktrees.map(PathUtilities.canonical))
        let selected = PathUtilities.canonical(selectedWorktree)
        guard allowed.contains(selected) else { throw CustomActionError.invalidWorktree(selectedWorktree) }
        let inputs = Dictionary(uniqueKeysWithValues: action.inputs.map { ($0.key, $0) })
        var expanded: [String] = []
        for token in try tokenize(action.commandTemplate) {
            guard token.hasPrefix("{{"), token.hasSuffix("}}") else {
                expanded.append(token)
                continue
            }
            let key = String(token.dropFirst(2).dropLast(2))
            guard let input = inputs[key] else { throw CustomActionError.invalidTemplate("unknown input {{\(key)}}") }
            let raw = values[key] ?? ""
            switch input.kind {
            case .flag:
                if raw == "true", let flag = input.flagArgument { expanded.append(flag) }
            case .worktree:
                let path = PathUtilities.canonical(raw)
                guard allowed.contains(path) else { throw CustomActionError.invalidWorktree(raw) }
                expanded.append(path)
            case .text:
                guard !raw.isEmpty else { throw CustomActionError.missingValue(key) }
                guard raw.count <= 500, !raw.contains("\0"), !raw.contains("\n"), !raw.contains("\r") else {
                    throw CustomActionError.invalidInput("{{\(key)}} contains an unsupported value")
                }
                expanded.append(raw)
            }
        }
        guard let executable = expanded.first, !executable.isEmpty else {
            throw CustomActionError.invalidTemplate("enter an executable")
        }
        let cwd = action.workingDirectory == .selectedWorktree ? selected : PathUtilities.canonical(repositoryRoot)
        return CustomActionPlan(
            executable: executable,
            arguments: Array(expanded.dropFirst()),
            currentDirectory: cwd,
            displayCommand: expanded.map(displayToken).joined(separator: " ")
        )
    }

    private static func tokenize(_ value: String, singleToken: Bool = false) throws -> [String] {
        if value.contains("$((") || value.contains("$(") || value.contains("`") {
            throw CustomActionError.invalidTemplate("shell expansion is not supported")
        }
        var tokens: [String] = [], current = "", quote: Character?, escaped = false
        let controls: Set<Character> = [";", "|", "<", ">"]
        for character in value {
            if escaped { current.append(character); escaped = false; continue }
            if character == "\\" { escaped = true; continue }
            if let active = quote {
                if character == active { quote = nil } else { current.append(character) }
                continue
            }
            if character == "\"" || character == "'" { quote = character; continue }
            if controls.contains(character) || character == "&" {
                throw CustomActionError.invalidTemplate("pipes, redirects, chaining, and background operators are not supported")
            }
            if character.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else { current.append(character) }
        }
        guard quote == nil, !escaped else { throw CustomActionError.invalidTemplate("a quote or escape is incomplete") }
        if !current.isEmpty { tokens.append(current) }
        if singleToken, tokens.count != 1 { throw CustomActionError.invalidInput("a checkbox argument must be one argument") }
        return tokens
    }

    private static func displayToken(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_./:@%+=,-]+$"#, options: .regularExpression) != nil { return value }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
