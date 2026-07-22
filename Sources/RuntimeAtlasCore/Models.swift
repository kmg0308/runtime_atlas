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
    public var databaseLabels: [String: String]
    public var appLanguage: AppLanguage?
    public var customActions: [CustomActionDefinition]

    public init(
        schemaVersion: Int = 2,
        repositories: [RepositoryRegistration] = [],
        databaseLabels: [String: String] = [:],
        appLanguage: AppLanguage? = nil,
        customActions: [CustomActionDefinition] = []
    ) {
        self.schemaVersion = schemaVersion
        self.repositories = repositories
        self.databaseLabels = databaseLabels
        self.appLanguage = appLanguage
        self.customActions = customActions
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, repositories, databaseLabels, appLanguage, customActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        repositories = try container.decodeIfPresent([RepositoryRegistration].self, forKey: .repositories) ?? []
        databaseLabels = try container.decodeIfPresent([String: String].self, forKey: .databaseLabels) ?? [:]
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage)
        customActions = try container.decodeIfPresent([CustomActionDefinition].self, forKey: .customActions) ?? []
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

    public init(
        id: UUID = UUID(), repositoryID: UUID, name: String, commandTemplate: String,
        kind: CustomActionKind = .task, risk: CustomActionRisk = .normal,
        workingDirectory: CustomActionWorkingDirectory = .selectedWorktree,
        effects: [String] = [], inputs: [CustomActionInputDefinition] = []
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

public enum EvidenceKind: String, Codable, CaseIterable, Sendable {
    case command
    case browser
    case manual
}

public enum EvidenceStatus: String, Codable, CaseIterable, Sendable {
    case pass = "PASS"
    case fail = "FAIL"
    case blocked = "BLOCKED"
    case pending = "PENDING"
}

public enum EvidenceDisplayStatus: String, Codable, Sendable {
    case pass = "PASS"
    case fail = "FAIL"
    case blocked = "BLOCKED"
    case pending = "PENDING"
    case stale = "STALE"
}

public struct EvidenceRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let kind: EvidenceKind
    public let status: EvidenceStatus
    public let worktreePath: String
    public let branch: String?
    public let sha: String
    public let dirty: Bool
    public let command: [String]?
    public let exitCode: Int32?
    public let startedAt: Date
    public let endedAt: Date
    public let note: String?
    public let viewport: String?

    public init(
        id: UUID = UUID(),
        kind: EvidenceKind,
        status: EvidenceStatus,
        worktreePath: String,
        branch: String?,
        sha: String,
        dirty: Bool,
        command: [String]?,
        exitCode: Int32?,
        startedAt: Date,
        endedAt: Date,
        note: String?,
        viewport: String?
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.worktreePath = worktreePath
        self.branch = branch
        self.sha = sha
        self.dirty = dirty
        self.command = command
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.viewport = viewport
    }
}

public struct EvidenceDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var records: [EvidenceRecord]

    public init(schemaVersion: Int = 1, records: [EvidenceRecord] = []) {
        self.schemaVersion = schemaVersion
        self.records = records
    }
}

public struct EvidencePresentation: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { record.id }

    public let record: EvidenceRecord
    public let displayStatus: EvidenceDisplayStatus

    public init(record: EvidenceRecord, displayStatus: EvidenceDisplayStatus) {
        self.record = record
        self.displayStatus = displayStatus
    }
}

public struct EvidenceCounts: Codable, Equatable, Sendable {
    public let pass: Int
    public let fail: Int
    public let blocked: Int
    public let pending: Int

    public init(pass: Int = 0, fail: Int = 0, blocked: Int = 0, pending: Int = 0) {
        self.pass = pass
        self.fail = fail
        self.blocked = blocked
        self.pending = pending
    }
}

public struct EvidenceOverview: Codable, Equatable, Sendable {
    public let latestCurrent: EvidencePresentation?
    public let currentCounts: EvidenceCounts
    public let history: [EvidencePresentation]

    public init(
        latestCurrent: EvidencePresentation?,
        currentCounts: EvidenceCounts,
        history: [EvidencePresentation]
    ) {
        self.latestCurrent = latestCurrent
        self.currentCounts = currentCounts
        self.history = history
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
    public let databaseLabel: String?
    public let processes: [RuntimeProcess]
    public let containers: [RuntimeContainer]
    public let evidence: EvidenceOverview

    public init(
        path: String,
        branch: String?,
        detached: Bool,
        sha: String,
        shortSHA: String,
        dirty: Bool,
        availability: AvailabilityState,
        unavailableReason: String?,
        databaseLabel: String?,
        processes: [RuntimeProcess],
        containers: [RuntimeContainer],
        evidence: EvidenceOverview
    ) {
        self.path = path
        self.branch = branch
        self.detached = detached
        self.sha = sha
        self.shortSHA = shortSHA
        self.dirty = dirty
        self.availability = availability
        self.unavailableReason = unavailableReason
        self.databaseLabel = databaseLabel
        self.processes = processes
        self.containers = containers
        self.evidence = evidence
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

public struct CurrentWorktree: Equatable, Sendable {
    public let path: String
    public let branch: String?
    public let sha: String
    public let dirty: Bool

    public init(path: String, branch: String?, sha: String, dirty: Bool) {
        self.path = path
        self.branch = branch
        self.sha = sha
        self.dirty = dirty
    }
}
