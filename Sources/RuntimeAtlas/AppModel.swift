import AppKit
import Foundation
import RuntimeAtlasCore

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published private(set) var status: AtlasStatus?
    @Published private(set) var isRefreshing = false
    @Published private(set) var language: AppLanguage
    @Published private(set) var customActions: [CustomActionDefinition]
    @Published private(set) var selectedWorktreePath: String?
    @Published private(set) var worktreeNavigationSession: WorktreeNavigationSession?
    @Published var operationMessage: String?
    @Published private(set) var languageSaveError: String?

    private let configurationStore: ConfigurationStore
    private let statusService: StatusService
    private let processTerminator: ProcessTerminator
    private var refreshTask: Task<Void, Never>?
    private var recentWorktreePaths: [String] = []
    var statusDidChange: ((AtlasStatus) -> Void)?

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        statusService: StatusService = StatusService(),
        processTerminator: ProcessTerminator = ProcessTerminator()
    ) {
        self.configurationStore = configurationStore
        self.statusService = statusService
        self.processTerminator = processTerminator
        let loadedConfiguration = try? configurationStore.load()
        language = loadedConfiguration?.value.appLanguage ?? .systemDefault
        customActions = loadedConfiguration?.value.customActions ?? []
    }

    var copy: AtlasCopy { AtlasCopy(language: language) }

    var selectedWorktree: WorktreeStatus? {
        guard let selectedWorktreePath else { return nil }
        return status?.repositories
            .flatMap(\.worktrees)
            .first { $0.path == selectedWorktreePath }
    }

    var selectedRepository: RepositoryStatus? {
        guard let path = selectedWorktreePath else { return nil }
        return status?.repositories.first { repository in repository.worktrees.contains { $0.path == path } }
    }

    var canCycleWorktrees: Bool {
        worktreePaths.count > 1
    }

    var worktreeSwitcherItems: [WorktreeStatus] {
        guard let session = worktreeNavigationSession else { return [] }
        let worktrees = status?.repositories.flatMap(\.worktrees) ?? []
        let worktreeByPath = Dictionary(uniqueKeysWithValues: worktrees.map { ($0.path, $0) })
        return session.paths.compactMap { worktreeByPath[$0] }
    }

    func actions(for repositoryID: UUID) -> [CustomActionDefinition] {
        customActions.filter { $0.repositoryID == repositoryID }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        operationMessage = nil
        let service = statusService
        let failureMessage = copy.refreshFailed

        refreshTask = Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (AtlasStatus?, String?) in
                do {
                    return (try service.makeStatus(), nil)
                } catch {
                    return (nil, failureMessage)
                }
            }.value

            isRefreshing = false
            if let refreshed = result.0 {
                status = refreshed
                customActions = (try? configurationStore.load().value.customActions) ?? customActions
                reconcileSelection(in: refreshed)
                statusDidChange?(refreshed)
            } else {
                operationMessage = result.1
            }
        }
    }

    func chooseRepository() {
        let panel = NSOpenPanel()
        panel.title = copy.addRepository
        panel.message = copy.chooseRepositoryMessage
        panel.prompt = copy.addRepository
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addRepository(path: url.path)
    }

    func addRepository(path: String) {
        do {
            try configurationStore.addRepository(path: path)
            refresh()
        } catch let error as LocalizedError {
            operationMessage = copy.localizedCoreMessage(error.errorDescription ?? copy.repositoryAddFailed)
        } catch {
            operationMessage = copy.repositoryAddFailed
        }
    }

    func removeRepository(_ repository: RepositoryStatus) {
        do {
            try configurationStore.removeRepository(id: repository.id)
            if repository.worktrees.contains(where: { $0.path == selectedWorktreePath }) {
                cancelWorktreeSwitcher()
                selectedWorktreePath = nil
            }
            refresh()
        } catch let error as LocalizedError {
            operationMessage = copy.localizedCoreMessage(error.errorDescription ?? copy.repositoryRemoveFailed)
        } catch {
            operationMessage = copy.repositoryRemoveFailed
        }
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        do {
            try configurationStore.setAppLanguage(newLanguage)
            language = newLanguage
            languageSaveError = nil
            operationMessage = nil
        } catch {
            languageSaveError = copy.languageSaveFailed
        }
    }

    @discardableResult
    func saveCustomAction(_ action: CustomActionDefinition) -> Bool {
        do {
            try configurationStore.saveCustomAction(action)
            customActions = try configurationStore.load().value.customActions
            operationMessage = copy.actionSaved
            return true
        } catch let error as CustomActionError {
            operationMessage = copy.customActionError(error)
            return false
        } catch let error as LocalizedError {
            operationMessage = copy.localizedCoreMessage(error.errorDescription ?? copy.actionSaveFailed)
            return false
        } catch {
            operationMessage = copy.actionSaveFailed
            return false
        }
    }

    func removeCustomAction(_ action: CustomActionDefinition) {
        do {
            try configurationStore.removeCustomAction(id: action.id)
            customActions = try configurationStore.load().value.customActions
        } catch {
            operationMessage = copy.actionRemoveFailed
        }
    }

    func select(worktree: WorktreeStatus) {
        cancelWorktreeSwitcher()
        selectWorktree(path: worktree.path)
    }

    func advanceWorktreeSwitcher(direction: WorktreeNavigationDirection) {
        recentWorktreePaths = WorktreeNavigation.reconciling(
            recentPaths: recentWorktreePaths,
            availablePaths: worktreePaths
        )
        worktreeNavigationSession = WorktreeNavigation.advancing(
            availablePaths: worktreePaths,
            currentPath: selectedWorktreePath,
            recentPaths: recentWorktreePaths,
            session: worktreeNavigationSession,
            direction: direction
        )
    }

    func commitWorktreeSwitcher() {
        guard let path = worktreeNavigationSession?.selectedPath else {
            worktreeNavigationSession = nil
            return
        }
        worktreeNavigationSession = nil
        selectWorktree(path: path)
    }

    func cancelWorktreeSwitcher() {
        worktreeNavigationSession = nil
    }

    func selectRecentWorktree(direction: WorktreeNavigationDirection) {
        advanceWorktreeSwitcher(direction: direction)
        commitWorktreeSwitcher()
    }

    func stopListeningProcess(_ process: RuntimeProcess, in worktree: WorktreeStatus) {
        let terminator = processTerminator
        Task {
            let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    try terminator.terminate(process, inWorktree: worktree.path)
                    return nil
                } catch let error as LocalizedError {
                    return error.errorDescription
                } catch {
                    return ProcessTerminationError.signalFailed.errorDescription
                }
            }.value

            if let failure {
                operationMessage = copy.localizedCoreMessage(failure)
                return
            }

            operationMessage = copy.processStopRequested(process.name)
            try? await Task.sleep(for: .milliseconds(800))
            refresh()
        }
    }

    @discardableResult
    func saveWorktreeOrder(in repository: RepositoryStatus, worktrees: [WorktreeStatus]) -> Bool {
        do {
            try configurationStore.setWorktreeOrder(
                repositoryID: repository.id,
                orderedKeys: worktrees.map {
                    WorktreeOrderIdentity.key(branch: $0.branch, detached: $0.detached, sha: $0.sha)
                }
            )
            refresh()
            return true
        } catch {
            operationMessage = copy.worktreeOrderSaveFailed
            return false
        }
    }

    private func reconcileSelection(in status: AtlasStatus) {
        let paths = status.repositories.flatMap(\.worktrees).map(\.path)
        cancelWorktreeSwitcher()
        recentWorktreePaths = WorktreeNavigation.reconciling(
            recentPaths: recentWorktreePaths,
            availablePaths: paths
        )
        if let selectedWorktreePath, paths.contains(selectedWorktreePath) {
            recentWorktreePaths = WorktreeNavigation.recording(
                selectedWorktreePath,
                in: recentWorktreePaths
            )
            return
        }
        guard let firstPath = paths.first else {
            selectedWorktreePath = nil
            return
        }
        selectWorktree(path: firstPath)
    }

    private func selectWorktree(path: String) {
        selectedWorktreePath = path
        recentWorktreePaths = WorktreeNavigation.recording(path, in: recentWorktreePaths)
    }

    private var worktreePaths: [String] {
        status?.repositories.flatMap(\.worktrees).map(\.path) ?? []
    }
}
