import Foundation

public enum EvidenceEvaluator {
    public static func overview(
        records: [EvidenceRecord],
        worktreePath: String,
        currentSHA: String
    ) -> EvidenceOverview {
        let canonicalPath = PathUtilities.canonical(worktreePath)
        let presentations = records
            .filter { PathUtilities.canonical($0.worktreePath) == canonicalPath }
            .sorted {
                if $0.endedAt != $1.endedAt { return $0.endedAt > $1.endedAt }
                return $0.id.uuidString > $1.id.uuidString
            }
            .map { record in
                EvidencePresentation(
                    record: record,
                    displayStatus: record.sha == currentSHA
                        ? displayStatus(for: record.status)
                        : .stale
                )
            }

        let current = presentations.filter { $0.displayStatus != .stale }
        let counts = EvidenceCounts(
            pass: current.filter { $0.displayStatus == .pass }.count,
            fail: current.filter { $0.displayStatus == .fail }.count,
            blocked: current.filter { $0.displayStatus == .blocked }.count,
            pending: current.filter { $0.displayStatus == .pending }.count
        )
        return EvidenceOverview(
            latestCurrent: current.first,
            currentCounts: counts,
            history: presentations
        )
    }

    public static func displayStatus(for status: EvidenceStatus) -> EvidenceDisplayStatus {
        switch status {
        case .pass: .pass
        case .fail: .fail
        case .blocked: .blocked
        case .pending: .pending
        }
    }
}

public enum PrivacySanitizer {
    private static let sensitiveFragments = [
        "password", "passwd", "token", "secret", "api-key", "api_key", "apikey",
        "authorization", "cookie", "session"
    ]

    private static let valueFlags: Set<String> = [
        "-h", "--header", "-u", "--user", "--proxy-user"
    ]

    private static let shellExecutables: Set<String> = [
        "bash", "dash", "fish", "sh", "zsh"
    ]

    public static func command(_ command: [String]) -> [String] {
        var result: [String] = []
        var redactNext = false
        var redactShellScript = false
        let executable = command.first.map {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased()
        }

        for (index, argument) in command.enumerated() {
            if redactShellScript {
                result.append("<redacted-shell-script>")
                redactShellScript = false
                continue
            }
            if redactNext {
                result.append("<redacted>")
                redactNext = false
                continue
            }

            let lowercased = argument.lowercased()
            if index > 0,
               let executable,
               shellExecutables.contains(executable),
               isShellCommandFlag(argument) {
                result.append(argument)
                redactShellScript = true
                continue
            }

            if (isSensitiveFlag(lowercased) || valueFlags.contains(lowercased)),
               !argument.contains("=") {
                result.append(argument)
                redactNext = true
                continue
            }

            if let equals = argument.firstIndex(of: "=") {
                let key = String(argument[..<equals]).lowercased()
                if containsSensitiveFragment(key)
                    || valueFlags.contains(key)
                    || key == "--header"
                    || key == "--proxy-user" {
                    result.append(String(argument[...equals]) + "<redacted>")
                    continue
                }
            }

            result.append(sanitizeInline(argument))
        }
        return result
    }

    public static func note(_ note: String) -> String {
        sanitizeInline(note)
    }

    public static func containsSensitiveContent(_ value: String) -> Bool {
        sanitizeInline(value) != value
    }

    private static func sanitizeInline(_ value: String) -> String {
        var sanitized = value
        let headerPattern = #"(?i)\b(authorization|proxy-authorization|cookie|set-cookie|x-api-key)\s*:\s*.+$"#
        if let regex = try? NSRegularExpression(pattern: headerPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "$1: <redacted>"
            )
        }

        let urlPattern = #"[A-Za-z][A-Za-z0-9+.-]*://\S+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "<redacted-url>"
            )
        }

        let assignmentPattern = #"(?i)\b(password|passwd|token|secret|api[-_]?key|authorization|cookie|session)\s*[:=]\s*\S+"#
        if let regex = try? NSRegularExpression(pattern: assignmentPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "$1=<redacted>"
            )
        }

        let bearerPattern = #"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]+"#
        if let regex = try? NSRegularExpression(pattern: bearerPattern) {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: range,
                withTemplate: "$1 <redacted>"
            )
        }
        return sanitized
    }

    private static func isSensitiveFlag(_ value: String) -> Bool {
        let key = value.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return containsSensitiveFragment(key)
    }

    private static func containsSensitiveFragment(_ value: String) -> Bool {
        sensitiveFragments.contains { value.contains($0) }
    }

    private static func isShellCommandFlag(_ value: String) -> Bool {
        guard value.hasPrefix("-"), !value.hasPrefix("--") else { return false }
        return value.dropFirst().contains("c")
    }
}

public enum EvidenceRecordingError: LocalizedError, Sendable {
    case emptyCommand
    case invalidKind
    case invalidViewport

    public var errorDescription: String? {
        switch self {
        case .emptyCommand:
            return "A command is required after --."
        case .invalidKind:
            return "record accepts only browser or manual evidence."
        case .invalidViewport:
            return "Viewport must be 1-64 plain text characters."
        }
    }
}

public struct VerificationRunResult: Sendable {
    public let exitCode: Int32
    public let record: EvidenceRecord
    public let evidenceSaveError: String?

    public init(exitCode: Int32, record: EvidenceRecord, evidenceSaveError: String?) {
        self.exitCode = exitCode
        self.record = record
        self.evidenceSaveError = evidenceSaveError
    }
}

public struct VerificationRunner: Sendable {
    private let gitInspector: GitInspector
    private let evidenceStore: EvidenceStore

    public init(
        gitInspector: GitInspector = GitInspector(),
        evidenceStore: EvidenceStore = EvidenceStore()
    ) {
        self.gitInspector = gitInspector
        self.evidenceStore = evidenceStore
    }

    public func run(
        command: [String],
        currentDirectory: URL,
        standardOutput: FileHandle = .standardOutput,
        standardError: FileHandle = .standardError
    ) throws -> VerificationRunResult {
        guard !command.isEmpty else { throw EvidenceRecordingError.emptyCommand }
        let worktree = try gitInspector.currentWorktree(at: currentDirectory)
        let startedAt = Date()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.currentDirectoryURL = currentDirectory
        process.standardInput = FileHandle.standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()

        let endedAt = Date()
        let exitCode = process.terminationStatus
        let record = EvidenceRecord(
            kind: .command,
            status: exitCode == 0 ? .pass : .fail,
            worktreePath: worktree.path,
            branch: worktree.branch,
            sha: worktree.sha,
            dirty: worktree.dirty,
            command: PrivacySanitizer.command(command),
            exitCode: exitCode,
            startedAt: startedAt,
            endedAt: endedAt,
            note: nil,
            viewport: nil
        )

        var saveError: String?
        do {
            try evidenceStore.append(record)
        } catch {
            saveError = "Evidence could not be saved."
        }
        return VerificationRunResult(exitCode: exitCode, record: record, evidenceSaveError: saveError)
    }
}

public struct ManualEvidenceRecorder: Sendable {
    private let gitInspector: GitInspector
    private let evidenceStore: EvidenceStore

    public init(
        gitInspector: GitInspector = GitInspector(),
        evidenceStore: EvidenceStore = EvidenceStore()
    ) {
        self.gitInspector = gitInspector
        self.evidenceStore = evidenceStore
    }

    @discardableResult
    public func record(
        kind: EvidenceKind,
        status: EvidenceStatus,
        note: String,
        viewport: String?,
        currentDirectory: URL
    ) throws -> EvidenceRecord {
        guard kind == .browser || kind == .manual else {
            throw EvidenceRecordingError.invalidKind
        }
        let normalizedViewport = try validateViewport(viewport)
        let worktree = try gitInspector.currentWorktree(at: currentDirectory)
        let now = Date()
        let record = EvidenceRecord(
            kind: kind,
            status: status,
            worktreePath: worktree.path,
            branch: worktree.branch,
            sha: worktree.sha,
            dirty: worktree.dirty,
            command: nil,
            exitCode: nil,
            startedAt: now,
            endedAt: now,
            note: PrivacySanitizer.note(note),
            viewport: normalizedViewport,
        )
        try evidenceStore.append(record)
        return record
    }

    private func validateViewport(_ viewport: String?) throws -> String? {
        guard let viewport else { return nil }
        let trimmed = viewport.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 64,
              trimmed.range(of: #"^[A-Za-z0-9 .x×_-]+$"#, options: .regularExpression) != nil else {
            throw EvidenceRecordingError.invalidViewport
        }
        return trimmed
    }
}
