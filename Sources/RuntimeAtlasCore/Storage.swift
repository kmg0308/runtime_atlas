import Darwin
import Foundation

public struct RuntimeAtlasPaths: Sendable {
    public let directory: URL
    public let configurationFile: URL
    public let actionSessionsFile: URL

    public init(baseDirectory: URL? = nil) {
        let resolvedDirectory: URL
        if let baseDirectory {
            resolvedDirectory = baseDirectory
        } else if let override = ProcessInfo.processInfo.environment["RUNTIME_ATLAS_HOME"],
                  !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
            resolvedDirectory = applicationSupport
                .appendingPathComponent("Runtime Atlas", isDirectory: true)
        }

        directory = resolvedDirectory.standardizedFileURL
        configurationFile = directory.appendingPathComponent("configuration.json")
        actionSessionsFile = directory.appendingPathComponent("action-sessions.json")
    }
}

public struct ActionSessionRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let actionID: UUID
    public let worktreePath: String
    public let supervisorPID: Int32
    public let identityToken: UUID?
    public let startedAt: Date

    public init(
        id: UUID = UUID(),
        actionID: UUID,
        worktreePath: String,
        supervisorPID: Int32,
        identityToken: UUID?,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.actionID = actionID
        self.worktreePath = PathUtilities.canonical(worktreePath)
        self.supervisorPID = supervisorPID
        self.identityToken = identityToken
        self.startedAt = startedAt
    }
}

public struct ActionSessionDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var sessions: [ActionSessionRecord]

    public init(schemaVersion: Int = 1, sessions: [ActionSessionRecord] = []) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
    }
}

public struct StoreLoad<Value: Sendable>: Sendable {
    public let value: Value
    public let recoveryNotice: String?

    public init(value: Value, recoveryNotice: String?) {
        self.value = value
        self.recoveryNotice = recoveryNotice
    }
}

public enum RuntimeAtlasStorageError: LocalizedError, Sendable {
    case cannotCreateDirectory
    case cannotLock
    case cannotWrite

    public var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory:
            return "Runtime Atlas could not create its local data directory."
        case .cannotLock:
            return "Runtime Atlas local data is busy or cannot be locked."
        case .cannotWrite:
            return "Runtime Atlas could not save local data."
        }
    }
}

private enum JSONCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private final class AdvisoryFileLock {
    private let descriptor: Int32

    init(lockFile: URL) throws {
        let path = lockFile.path
        descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw RuntimeAtlasStorageError.cannotLock
        }
        guard flock(descriptor, LOCK_EX) == 0 else {
            Darwin.close(descriptor)
            throw RuntimeAtlasStorageError.cannotLock
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }
}

private struct AtomicJSONFile<Document: Codable & Sendable>: Sendable {
    let fileURL: URL
    let emptyDocument: @Sendable () -> Document
    let damagedFileDescription: String

    func load() throws -> StoreLoad<Document> {
        try prepareDirectory()
        let lock = try AdvisoryFileLock(lockFile: lockFileURL)
        defer { withExtendedLifetime(lock) {} }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StoreLoad(value: emptyDocument(), recoveryNotice: nil)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let document = try JSONCoding.decoder().decode(Document.self, from: data)
            return StoreLoad(value: document, recoveryNotice: nil)
        } catch {
            return StoreLoad(
                value: emptyDocument(),
                recoveryNotice: damagedFileDescription
            )
        }
    }

    @discardableResult
    func update(_ mutation: (inout Document) throws -> Void) throws -> String? {
        try prepareDirectory()
        let lock = try AdvisoryFileLock(lockFile: lockFileURL)
        defer { withExtendedLifetime(lock) {} }

        var document = emptyDocument()
        var recoveryNotice: String?

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                document = try JSONCoding.decoder().decode(Document.self, from: data)
            } catch {
                try preserveDamagedFile()
                recoveryNotice = damagedFileDescription
            }
        }

        try mutation(&document)
        do {
            let data = try JSONCoding.encoder().encode(document)
            try data.write(to: fileURL, options: .atomic)
            guard chmod(fileURL.path, S_IRUSR | S_IWUSR) == 0 else {
                throw RuntimeAtlasStorageError.cannotWrite
            }
        } catch let error as RuntimeAtlasStorageError {
            throw error
        } catch {
            throw RuntimeAtlasStorageError.cannotWrite
        }

        return recoveryNotice
    }

    private var lockFileURL: URL {
        fileURL.appendingPathExtension("lock")
    }

    private func prepareDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard chmod(fileURL.deletingLastPathComponent().path, S_IRWXU) == 0 else {
                throw RuntimeAtlasStorageError.cannotCreateDirectory
            }
        } catch {
            throw RuntimeAtlasStorageError.cannotCreateDirectory
        }
    }

    private func preserveDamagedFile() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = formatter.string(from: Date())
        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(suffix)-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            guard chmod(backupURL.path, S_IRUSR | S_IWUSR) == 0 else {
                throw RuntimeAtlasStorageError.cannotWrite
            }
        } catch {
            throw RuntimeAtlasStorageError.cannotWrite
        }
    }
}

public struct ConfigurationStore: Sendable {
    private let file: AtomicJSONFile<RuntimeAtlasConfiguration>
    private let repositoryRootResolver: @Sendable (String) -> String?

    public init(paths: RuntimeAtlasPaths = RuntimeAtlasPaths()) {
        self.init(paths: paths, repositoryRootResolver: Self.resolveGitRoot)
    }

    public init(
        paths: RuntimeAtlasPaths,
        repositoryRootResolver: @escaping @Sendable (String) -> String?
    ) {
        file = AtomicJSONFile(
            fileURL: paths.configurationFile,
            emptyDocument: { RuntimeAtlasConfiguration() },
            damagedFileDescription: "The repository configuration file is damaged; an empty configuration is being used until the next save."
        )
        self.repositoryRootResolver = repositoryRootResolver
    }

    public func load() throws -> StoreLoad<RuntimeAtlasConfiguration> {
        try file.load()
    }

    @discardableResult
    public func addRepository(path: String) throws -> UUID {
        let selectedPath = PathUtilities.canonical(path)
        let canonical = repositoryRootResolver(selectedPath) ?? selectedPath
        var resolvedID = UUID()
        try file.update { configuration in
            if let existing = configuration.repositories.first(where: { $0.path == canonical }) {
                resolvedID = existing.id
                return
            }
            let registration = RepositoryRegistration(id: resolvedID, path: canonical)
            configuration.repositories.append(registration)
            configuration.repositories.sort { $0.addedAt < $1.addedAt }
        }
        return resolvedID
    }

    private static func resolveGitRoot(_ path: String) -> String? {
        guard let result = try? CommandExecutor().run(
            executable: ExecutableLocator.git,
            arguments: ["--no-optional-locks", "-C", path, "rev-parse", "--show-toplevel"]
        ), result.exitCode == 0 else {
            return nil
        }
        let root = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return root.isEmpty ? nil : PathUtilities.canonical(root)
    }

    public func removeRepository(id: UUID) throws {
        try file.update { configuration in
            configuration.repositories.removeAll { $0.id == id }
            configuration.customActions.removeAll { $0.repositoryID == id }
            configuration.worktreeOrderByRepository.removeValue(forKey: id.uuidString)
        }
    }

    public func setAppLanguage(_ language: AppLanguage) throws {
        try file.update { configuration in
            configuration.appLanguage = language
        }
    }

    public func setWorktreeOrder(repositoryID: UUID, orderedKeys: [String]) throws {
        let uniqueKeys = orderedKeys.reduce(into: [String]()) { result, key in
            if !result.contains(key) { result.append(key) }
        }
        try file.update { configuration in
            guard configuration.repositories.contains(where: { $0.id == repositoryID }) else {
                throw CustomActionError.invalidInput("repository is no longer registered")
            }
            configuration.schemaVersion = max(configuration.schemaVersion, 3)
            configuration.worktreeOrderByRepository[repositoryID.uuidString] = uniqueKeys
        }
    }

    public func saveCustomAction(_ action: CustomActionDefinition) throws {
        try CustomActionPlanner.validate(action)
        try file.update { configuration in
            guard configuration.repositories.contains(where: { $0.id == action.repositoryID }) else {
                throw CustomActionError.invalidInput("repository is no longer registered")
            }
            configuration.schemaVersion = max(configuration.schemaVersion, 2)
            if let index = configuration.customActions.firstIndex(where: { $0.id == action.id }) {
                configuration.customActions[index] = action
            } else {
                configuration.customActions.append(action)
            }
        }
    }

    public func removeCustomAction(id: UUID) throws {
        try file.update { configuration in
            configuration.customActions.removeAll { $0.id == id }
        }
    }
}

public struct ActionSessionStore: Sendable {
    private let file: AtomicJSONFile<ActionSessionDocument>

    public init(paths: RuntimeAtlasPaths = RuntimeAtlasPaths()) {
        file = AtomicJSONFile(
            fileURL: paths.actionSessionsFile,
            emptyDocument: { ActionSessionDocument() },
            damagedFileDescription: "The command session file is damaged; running command buttons may need to be started again."
        )
    }

    public func load() throws -> StoreLoad<ActionSessionDocument> {
        try file.load()
    }

    public func upsert(_ record: ActionSessionRecord) throws {
        try file.update { document in
            document.sessions.removeAll {
                $0.actionID == record.actionID
                    && PathUtilities.canonical($0.worktreePath) == record.worktreePath
            }
            document.sessions.append(record)
        }
    }

    public func remove(id: UUID) throws {
        try file.update { document in
            document.sessions.removeAll { $0.id == id }
        }
    }

    public func replace(with sessions: [ActionSessionRecord]) throws {
        try file.update { document in
            document.sessions = sessions
        }
    }
}

public enum ActionSessionMatcher {
    public static func matches(_ record: ActionSessionRecord, commandLine: String) -> Bool {
        guard commandLine.contains("runtime-atlas-supervisor") else { return false }
        if let token = record.identityToken {
            return commandLine.contains("--session-id \(token.uuidString)")
        }
        return commandLine.contains("--cwd \(record.worktreePath) --")
    }
}

public enum PathUtilities {
    public static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    public static func isSameOrDescendant(_ candidate: String, of root: String) -> Bool {
        let canonicalCandidate = canonical(candidate)
        let canonicalRoot = canonical(root)
        return canonicalCandidate == canonicalRoot
            || canonicalCandidate.hasPrefix(canonicalRoot.hasSuffix("/") ? canonicalRoot : canonicalRoot + "/")
    }
}
