import Foundation

public struct ParsedGitWorktree: Equatable, Sendable {
    public var path: String
    public var sha: String
    public var branch: String?
    public var detached: Bool
    public var prunable: Bool

    public init(
        path: String = "",
        sha: String = "",
        branch: String? = nil,
        detached: Bool = false,
        prunable: Bool = false
    ) {
        self.path = path
        self.sha = sha
        self.branch = branch
        self.detached = detached
        self.prunable = prunable
    }
}

public enum GitWorktreeParser {
    public static func parse(_ output: String) -> [ParsedGitWorktree] {
        var result: [ParsedGitWorktree] = []
        var current: ParsedGitWorktree?

        func finishCurrent() {
            if let current, !current.path.isEmpty {
                result.append(current)
            }
            current = nil
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty {
                finishCurrent()
                continue
            }

            if line.hasPrefix("worktree ") {
                finishCurrent()
                current = ParsedGitWorktree(path: String(line.dropFirst("worktree ".count)))
            } else if line.hasPrefix("HEAD ") {
                current?.sha = String(line.dropFirst("HEAD ".count))
            } else if line.hasPrefix("branch ") {
                let reference = String(line.dropFirst("branch ".count))
                current?.branch = reference.hasPrefix("refs/heads/")
                    ? String(reference.dropFirst("refs/heads/".count))
                    : reference
            } else if line == "detached" {
                current?.detached = true
            } else if line.hasPrefix("prunable") {
                current?.prunable = true
            }
        }
        finishCurrent()
        return result
    }
}

public struct InspectedWorktree: Equatable, Sendable {
    public let path: String
    public let branch: String?
    public let detached: Bool
    public let sha: String
    public let dirty: Bool
    public let availability: AvailabilityState
    public let unavailableReason: String?
}

public struct InspectedRepository: Equatable, Sendable {
    public let registration: RepositoryRegistration
    public let name: String
    public let availability: AvailabilityState
    public let unavailableReason: String?
    public let worktrees: [InspectedWorktree]
}

public enum CurrentWorktreeError: LocalizedError, Sendable {
    case notInsideWorktree

    public var errorDescription: String? {
        "The current directory is not inside an available Git worktree."
    }
}

public struct GitInspector: Sendable {
    private let executor: CommandExecutor

    public init(executor: CommandExecutor = CommandExecutor()) {
        self.executor = executor
    }

    public func inspectRepository(_ registration: RepositoryRegistration) -> InspectedRepository {
        let path = PathUtilities.canonical(registration.path)
        let name = URL(fileURLWithPath: path).lastPathComponent

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return InspectedRepository(
                registration: registration,
                name: name,
                availability: .unavailable,
                unavailableReason: "Repository path is missing.",
                worktrees: []
            )
        }

        let listing: CommandResult
        do {
            listing = try executor.run(
                executable: ExecutableLocator.git,
                arguments: ["--no-optional-locks", "-C", path, "worktree", "list", "--porcelain"]
            )
        } catch {
            return unavailableRepository(registration, name: name, reason: "Git could not inspect this repository.")
        }

        guard listing.exitCode == 0 else {
            return unavailableRepository(registration, name: name, reason: "Path is not an available Git repository.")
        }

        let parsed = GitWorktreeParser.parse(listing.standardOutput)
        guard !parsed.isEmpty else {
            return unavailableRepository(registration, name: name, reason: "No Git worktrees were found.")
        }

        let worktrees = parsed.map(inspectWorktree)
        return InspectedRepository(
            registration: registration,
            name: name,
            availability: .available,
            unavailableReason: nil,
            worktrees: worktrees
        )
    }

    public func currentWorktree(at directory: URL) throws -> CurrentWorktree {
        let workingDirectory = directory.standardizedFileURL
        let rootResult = try executor.run(
            executable: ExecutableLocator.git,
            arguments: ["--no-optional-locks", "-C", workingDirectory.path, "rev-parse", "--show-toplevel"]
        )
        guard rootResult.exitCode == 0 else { throw CurrentWorktreeError.notInsideWorktree }

        let path = PathUtilities.canonical(rootResult.standardOutput.trimmed)
        guard !path.isEmpty else { throw CurrentWorktreeError.notInsideWorktree }

        let shaResult = try executor.run(
            executable: ExecutableLocator.git,
            arguments: ["--no-optional-locks", "-C", path, "rev-parse", "HEAD"]
        )
        guard shaResult.exitCode == 0 else { throw CurrentWorktreeError.notInsideWorktree }

        let branchResult = try executor.run(
            executable: ExecutableLocator.git,
            arguments: ["--no-optional-locks", "-C", path, "symbolic-ref", "--quiet", "--short", "HEAD"]
        )
        let statusResult = try executor.run(
            executable: ExecutableLocator.git,
            arguments: ["--no-optional-locks", "-C", path, "status", "--porcelain", "--untracked-files=normal"]
        )
        guard statusResult.exitCode == 0 else { throw CurrentWorktreeError.notInsideWorktree }

        return CurrentWorktree(
            path: path,
            branch: branchResult.exitCode == 0 ? branchResult.standardOutput.trimmed.nilIfEmpty : nil,
            sha: shaResult.standardOutput.trimmed,
            dirty: !statusResult.standardOutput.isEmpty
        )
    }

    private func inspectWorktree(_ parsed: ParsedGitWorktree) -> InspectedWorktree {
        let path = PathUtilities.canonical(parsed.path)
        var isDirectory: ObjCBool = false
        guard !parsed.prunable,
              FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return InspectedWorktree(
                path: path,
                branch: parsed.branch,
                detached: parsed.detached,
                sha: parsed.sha,
                dirty: false,
                availability: .unavailable,
                unavailableReason: "Worktree path is missing."
            )
        }

        do {
            let status = try executor.run(
                executable: ExecutableLocator.git,
                arguments: ["--no-optional-locks", "-C", path, "status", "--porcelain", "--untracked-files=normal"]
            )
            guard status.exitCode == 0 else {
                return unavailableWorktree(parsed, canonicalPath: path)
            }
            return InspectedWorktree(
                path: path,
                branch: parsed.branch,
                detached: parsed.detached,
                sha: parsed.sha,
                dirty: !status.standardOutput.isEmpty,
                availability: .available,
                unavailableReason: nil
            )
        } catch {
            return unavailableWorktree(parsed, canonicalPath: path)
        }
    }

    private func unavailableWorktree(_ parsed: ParsedGitWorktree, canonicalPath: String) -> InspectedWorktree {
        InspectedWorktree(
            path: canonicalPath,
            branch: parsed.branch,
            detached: parsed.detached,
            sha: parsed.sha,
            dirty: false,
            availability: .unavailable,
            unavailableReason: "Git could not inspect this worktree."
        )
    }

    private func unavailableRepository(
        _ registration: RepositoryRegistration,
        name: String,
        reason: String
    ) -> InspectedRepository {
        InspectedRepository(
            registration: registration,
            name: name,
            availability: .unavailable,
            unavailableReason: reason,
            worktrees: []
        )
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
