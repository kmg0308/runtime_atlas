import AppKit
import Foundation
import RuntimeAtlasCore

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published private(set) var status: AtlasStatus?
    @Published private(set) var isRefreshing = false
    @Published private(set) var language: AppLanguage
    @Published private(set) var customActions: [CustomActionDefinition]
    @Published var selectedWorktreePath: String?
    @Published var operationMessage: String?
    @Published private(set) var languageSaveError: String?

    private let configurationStore: ConfigurationStore
    private let statusService: StatusService
    private let processTerminator: ProcessTerminator
    private var refreshTask: Task<Void, Never>?
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
        selectedWorktreePath = worktree.path
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
        if let selectedWorktreePath, paths.contains(selectedWorktreePath) {
            return
        }
        selectedWorktreePath = paths.first
    }
}
