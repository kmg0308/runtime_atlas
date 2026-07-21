import Foundation

public struct StatusService: Sendable {
    private let configurationStore: ConfigurationStore
    private let evidenceStore: EvidenceStore
    private let gitInspector: GitInspector
    private let processDetector: ProcessDetector
    private let dockerDetector: DockerDetector

    public init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        evidenceStore: EvidenceStore = EvidenceStore(),
        gitInspector: GitInspector = GitInspector(),
        processDetector: ProcessDetector = ProcessDetector(),
        dockerDetector: DockerDetector = DockerDetector()
    ) {
        self.configurationStore = configurationStore
        self.evidenceStore = evidenceStore
        self.gitInspector = gitInspector
        self.processDetector = processDetector
        self.dockerDetector = dockerDetector
    }

    public func makeStatus() throws -> AtlasStatus {
        let configurationLoad = try configurationStore.load()
        let evidenceLoad = try evidenceStore.load()
        let processDiscovery = processDetector.detect()
        let dockerDiscovery = dockerDetector.detect()

        var notices: [AtlasNotice] = []
        if let recovery = configurationLoad.recoveryNotice {
            notices.append(AtlasNotice(kind: .error, message: recovery))
        }
        if let recovery = evidenceLoad.recoveryNotice {
            notices.append(AtlasNotice(kind: .error, message: recovery))
        }

        let configuration = configurationLoad.value
        let repositories = configuration.repositories.map { registration in
            let inspected = gitInspector.inspectRepository(registration)
            let worktrees = inspected.worktrees
                .map { worktree in
                    makeWorktreeStatus(
                        worktree,
                        configuration: configuration,
                        evidence: evidenceLoad.value.records,
                        processDiscovery: processDiscovery,
                        dockerDiscovery: dockerDiscovery
                    )
                }
                .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

            return RepositoryStatus(
                id: registration.id,
                path: registration.path,
                name: inspected.name,
                availability: inspected.availability,
                unavailableReason: inspected.unavailableReason,
                worktrees: worktrees
            )
        }

        return AtlasStatus(
            processDiscovery: processDiscovery.availability,
            dockerDiscovery: dockerDiscovery.availability,
            notices: notices,
            repositories: repositories
        )
    }

    private func makeWorktreeStatus(
        _ worktree: InspectedWorktree,
        configuration: RuntimeAtlasConfiguration,
        evidence: [EvidenceRecord],
        processDiscovery: ProcessDiscoveryResult,
        dockerDiscovery: DockerDiscoveryResult
    ) -> WorktreeStatus {
        let path = PathUtilities.canonical(worktree.path)
        let mappedProcesses = processDiscovery.processes
            .filter { process in
                guard let cwd = process.cwd else { return false }
                return PathUtilities.isSameOrDescendant(cwd, of: path)
            }
            .sorted { lhs, rhs in
                lhs.name == rhs.name ? lhs.pid < rhs.pid : lhs.name < rhs.name
            }

        let mappedContainers = dockerDiscovery.containers
            .filter { container in
                container.mountSources.contains { source in
                    PathUtilities.isSameOrDescendant(source, of: path)
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return WorktreeStatus(
            path: path,
            branch: worktree.branch,
            detached: worktree.detached,
            sha: worktree.sha,
            shortSHA: String(worktree.sha.prefix(7)),
            dirty: worktree.dirty,
            availability: worktree.availability,
            unavailableReason: worktree.unavailableReason,
            databaseLabel: configuration.databaseLabels[path],
            processes: mappedProcesses,
            containers: mappedContainers,
            evidence: EvidenceEvaluator.overview(
                records: evidence,
                worktreePath: path,
                currentSHA: worktree.sha
            )
        )
    }
}

public enum StatusJSONEncoder {
    public static func encode(_ status: AtlasStatus) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(status)
    }
}
