import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"

    public var id: String { rawValue }

    public static var systemDefault: AppLanguage {
        preferred(for: Locale.preferredLanguages)
    }

    public static func preferred(for languageIdentifiers: [String]) -> AppLanguage {
        guard let first = languageIdentifiers.first?.lowercased() else { return .english }
        return first.hasPrefix("ko") ? .korean : .english
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}

public enum AvailabilityState: String, Codable, Sendable {
    case available
    case unavailable
}

public struct DiscoveryAvailability: Codable, Equatable, Sendable {
    public let state: AvailabilityState
    public let reason: String?

    public init(state: AvailabilityState, reason: String? = nil) {
        self.state = state
        self.reason = reason
    }

    public static let available = DiscoveryAvailability(state: .available)
}

public struct AtlasNotice: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case warning
        case error
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public struct RepositoryRegistration: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let addedAt: Date

    public init(id: UUID = UUID(), path: String, addedAt: Date = Date()) {
        self.id = id
        self.path = path
        self.addedAt = addedAt
    }
}

public struct RuntimeAtlasConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var repositories: [RepositoryRegistration]
    public var appLanguage: AppLanguage?
    public var customActions: [CustomActionDefinition]
    public var worktreeOrderByRepository: [String: [String]]

    public init(
        schemaVersion: Int = 2,
        repositories: [RepositoryRegistration] = [],
        appLanguage: AppLanguage? = nil,
        customActions: [CustomActionDefinition] = [],
        worktreeOrderByRepository: [String: [String]] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.repositories = repositories
        self.appLanguage = appLanguage
        self.customActions = customActions
        self.worktreeOrderByRepository = worktreeOrderByRepository
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, repositories, appLanguage, customActions, worktreeOrderByRepository
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        repositories = try container.decodeIfPresent([RepositoryRegistration].self, forKey: .repositories) ?? []
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage)
        customActions = try container.decodeIfPresent([CustomActionDefinition].self, forKey: .customActions) ?? []
        worktreeOrderByRepository = try container.decodeIfPresent(
            [String: [String]].self,
            forKey: .worktreeOrderByRepository
        ) ?? [:]
    }
}

public enum WorktreeOrderIdentity {
    public static func key(branch: String?, detached: Bool, sha: String) -> String {
        if !detached, let branch, !branch.isEmpty {
            return "branch:\(branch)"
        }
        return "detached:\(sha)"
    }
}

public enum WorktreeNavigationDirection: Sendable {
    case next
    case previous
}

public struct WorktreeNavigationSession: Equatable, Sendable {
    public let paths: [String]
    public let selectedIndex: Int

    public init(paths: [String], selectedIndex: Int) {
        self.paths = paths
        self.selectedIndex = selectedIndex
    }

    public var selectedPath: String? {
        paths.indices.contains(selectedIndex) ? paths[selectedIndex] : nil
    }
}

public enum WorktreeNavigation {
    private static let recentLimit = 20

    public static func recording(_ path: String, in recentPaths: [String]) -> [String] {
        Array(([path] + recentPaths.filter { $0 != path }).prefix(recentLimit))
    }

    public static func reconciling(
        recentPaths: [String],
        availablePaths: [String]
    ) -> [String] {
        let availablePaths = unique(availablePaths)
        let available = Set(availablePaths)
        let recentPaths = unique(recentPaths).filter(available.contains)
        let recent = recentPaths + availablePaths.filter { !recentPaths.contains($0) }
        return Array(recent.prefix(recentLimit))
    }

    public static func advancing(
        availablePaths: [String],
        currentPath: String?,
        recentPaths: [String],
        session: WorktreeNavigationSession?,
        direction: WorktreeNavigationDirection
    ) -> WorktreeNavigationSession? {
        let availablePaths = unique(availablePaths)
        guard availablePaths.count > 1 else { return nil }
        let available = Set(availablePaths)

        let paths: [String]
        let startingIndex: Int
        if let session {
            paths = session.paths.filter(available.contains)
            guard paths.count > 1 else { return nil }
            startingIndex = session.selectedPath.flatMap(paths.firstIndex(of:)) ?? 0
        } else {
            let reconciled = reconciling(recentPaths: recentPaths, availablePaths: availablePaths)
            if let currentPath, reconciled.contains(currentPath) {
                paths = recording(currentPath, in: reconciled)
                startingIndex = 0
            } else {
                paths = reconciled
                startingIndex = direction == .next ? paths.count - 1 : 0
            }
        }

        let offset = direction == .next ? 1 : -1
        let selectedIndex = (startingIndex + offset + paths.count) % paths.count
        return WorktreeNavigationSession(paths: paths, selectedIndex: selectedIndex)
    }

    private static func unique(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }
}

public enum CustomActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case task
    case session
    public var id: String { rawValue }
}

public enum CustomActionRisk: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case destructive
    public var id: String { rawValue }
}

public enum CustomActionWorkingDirectory: String, Codable, CaseIterable, Identifiable, Sendable {
    case selectedWorktree
    case repositoryRoot
    public var id: String { rawValue }
}

public enum CustomActionInputKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case worktree
    case flag
    public var id: String { rawValue }
}

public struct CustomActionInputDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var key: String
    public var label: String
    public var kind: CustomActionInputKind
    public var flagArgument: String?

    public init(id: UUID = UUID(), key: String, label: String, kind: CustomActionInputKind, flagArgument: String? = nil) {
        self.id = id
        self.key = key
        self.label = label
        self.kind = kind
        self.flagArgument = flagArgument
    }
}

public struct CustomActionDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var repositoryID: UUID
    public var name: String
    public var commandTemplate: String
    public var kind: CustomActionKind
    public var risk: CustomActionRisk
    public var workingDirectory: CustomActionWorkingDirectory
    public var effects: [String]
    public var inputs: [CustomActionInputDefinition]
    public var detectsRunningWorktreeListener: Bool

    public init(
        id: UUID = UUID(), repositoryID: UUID, name: String, commandTemplate: String,
        kind: CustomActionKind = .task, risk: CustomActionRisk = .normal,
        workingDirectory: CustomActionWorkingDirectory = .selectedWorktree,
        effects: [String] = [], inputs: [CustomActionInputDefinition] = [],
        detectsRunningWorktreeListener: Bool? = nil
    ) {
        self.id = id
        self.repositoryID = repositoryID
        self.name = name
        self.commandTemplate = commandTemplate
        self.kind = kind
        self.risk = risk
        self.workingDirectory = workingDirectory
        self.effects = effects
        self.inputs = inputs
        self.detectsRunningWorktreeListener = detectsRunningWorktreeListener
            ?? (kind == .session && workingDirectory == .selectedWorktree)
    }

    private enum CodingKeys: String, CodingKey {
        case id, repositoryID, name, commandTemplate, kind, risk, workingDirectory, effects, inputs
        case detectsRunningWorktreeListener
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        repositoryID = try container.decode(UUID.self, forKey: .repositoryID)
        name = try container.decode(String.self, forKey: .name)
        commandTemplate = try container.decode(String.self, forKey: .commandTemplate)
        kind = try container.decode(CustomActionKind.self, forKey: .kind)
        risk = try container.decode(CustomActionRisk.self, forKey: .risk)
        workingDirectory = try container.decode(CustomActionWorkingDirectory.self, forKey: .workingDirectory)
        effects = try container.decodeIfPresent([String].self, forKey: .effects) ?? []
        inputs = try container.decodeIfPresent([CustomActionInputDefinition].self, forKey: .inputs) ?? []
        detectsRunningWorktreeListener = try container.decodeIfPresent(
            Bool.self,
            forKey: .detectsRunningWorktreeListener
        ) ?? (kind == .session && workingDirectory == .selectedWorktree)
    }
}

public struct ListeningPort: Codable, Equatable, Hashable, Sendable {
    public let address: String
    public let port: Int

    public init(address: String, port: Int) {
        self.address = address
        self.port = port
    }
}

public struct RuntimeProcess: Codable, Equatable, Sendable, Identifiable {
    public var id: Int32 { pid }

    public let pid: Int32
    public let name: String
    public let cwd: String?
    public let ports: [ListeningPort]

    public init(pid: Int32, name: String, cwd: String?, ports: [ListeningPort]) {
        self.pid = pid
        self.name = name
        self.cwd = cwd
        self.ports = ports
    }
}

public struct PublishedPort: Codable, Equatable, Hashable, Sendable {
    public let hostIP: String
    public let hostPort: Int
    public let containerPort: Int
    public let transport: String

    public init(hostIP: String, hostPort: Int, containerPort: Int, transport: String) {
        self.hostIP = hostIP
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.transport = transport
    }
}

public struct RuntimeContainer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let image: String
    public let mountSources: [String]
    public let ports: [PublishedPort]

    public init(
        id: String,
        name: String,
        image: String,
        mountSources: [String],
        ports: [PublishedPort]
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.mountSources = mountSources
        self.ports = ports
    }
}

public struct WorktreeStatus: Codable, Equatable, Sendable, Identifiable {
    public var id: String { path }

    public let path: String
    public let branch: String?
    public let detached: Bool
    public let sha: String
    public let shortSHA: String
    public let dirty: Bool
    public let availability: AvailabilityState
    public let unavailableReason: String?
    public let processes: [RuntimeProcess]
    public let containers: [RuntimeContainer]

    public init(
        path: String,
        branch: String?,
        detached: Bool,
        sha: String,
        shortSHA: String,
        dirty: Bool,
        availability: AvailabilityState,
        unavailableReason: String?,
        processes: [RuntimeProcess],
        containers: [RuntimeContainer]
    ) {
        self.path = path
        self.branch = branch
        self.detached = detached
        self.sha = sha
        self.shortSHA = shortSHA
        self.dirty = dirty
        self.availability = availability
        self.unavailableReason = unavailableReason
        self.processes = processes
        self.containers = containers
    }
}

public struct RepositoryStatus: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let path: String
    public let name: String
    public let availability: AvailabilityState
    public let unavailableReason: String?
    public let worktrees: [WorktreeStatus]

    public init(
        id: UUID,
        path: String,
        name: String,
        availability: AvailabilityState,
        unavailableReason: String?,
        worktrees: [WorktreeStatus]
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.availability = availability
        self.unavailableReason = unavailableReason
        self.worktrees = worktrees
    }
}

public struct AtlasStatus: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let processDiscovery: DiscoveryAvailability
    public let dockerDiscovery: DiscoveryAvailability
    public let notices: [AtlasNotice]
    public let repositories: [RepositoryStatus]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        processDiscovery: DiscoveryAvailability,
        dockerDiscovery: DiscoveryAvailability,
        notices: [AtlasNotice],
        repositories: [RepositoryStatus]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.processDiscovery = processDiscovery
        self.dockerDiscovery = dockerDiscovery
        self.notices = notices
        self.repositories = repositories
    }
}
