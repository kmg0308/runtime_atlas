import AppKit
import Foundation
import RuntimeAtlasCore

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published private(set) var status: AtlasStatus?
    @Published private(set) var isRefreshing = false
    @Published private(set) var language: AppLanguage
    @Published var selectedWorktreePath: String?
    @Published var operationMessage: String?
    @Published private(set) var languageSaveError: String?

    private let configurationStore: ConfigurationStore
    private let statusService: StatusService
    private var refreshTask: Task<Void, Never>?

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        statusService: StatusService = StatusService()
    ) {
        self.configurationStore = configurationStore
        self.statusService = statusService
        let loadedConfiguration = try? configurationStore.load()
        language = loadedConfiguration?.value.appLanguage ?? .systemDefault
    }

    var copy: AtlasCopy { AtlasCopy(language: language) }

    var selectedWorktree: WorktreeStatus? {
        guard let selectedWorktreePath else { return nil }
        return status?.repositories
            .flatMap(\.worktrees)
            .first { $0.path == selectedWorktreePath }
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
                reconcileSelection(in: refreshed)
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
            try configurationStore.removeRepository(
                id: repository.id,
                worktreePaths: repository.worktrees.map(\.path)
            )
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

    @discardableResult
    func saveDatabaseLabel(_ label: String, for worktree: WorktreeStatus) -> Bool {
        do {
            try configurationStore.setDatabaseLabel(label, forWorktree: worktree.path)
            refresh()
            operationMessage = copy.logicalDBSaved
            return true
        } catch DatabaseLabelError.invalid {
            operationMessage = copy.logicalDBValidation
            return false
        } catch let error as LocalizedError {
            operationMessage = copy.localizedCoreMessage(error.errorDescription ?? copy.logicalDBSaveFailed)
            return false
        } catch {
            operationMessage = copy.logicalDBSaveFailed
            return false
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

    func select(worktree: WorktreeStatus) {
        selectedWorktreePath = worktree.path
    }

    private func reconcileSelection(in status: AtlasStatus) {
        let paths = status.repositories.flatMap(\.worktrees).map(\.path)
        if let selectedWorktreePath, paths.contains(selectedWorktreePath) {
            return
        }
        selectedWorktreePath = paths.first
    }
}
