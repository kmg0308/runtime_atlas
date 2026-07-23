import Foundation
import RuntimeAtlasCore
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var updates: UpdateModel
    @EnvironmentObject private var actionRunner: ActionRunner
    @Environment(\.atlasCopy) private var copy
    @State private var repositoryToRemove: RepositoryStatus?

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HSplitView {
            SidebarView(repositoryToRemove: $repositoryToRemove)
                .environmentObject(model)
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 360)

            VStack(spacing: 0) {
                if updates.isUpdateAvailable {
                    UpdateAvailableBanner()
                        .environmentObject(updates)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }
                DetailPane()
                    .environmentObject(model)
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(RuntimeAtlasTheme.primaryText)
        .background(RuntimeAtlasTheme.background)
        .task {
            if model.status == nil {
                model.refresh()
            }
            updates.startAutoChecks()
        }
        .onReceive(refreshTimer) { _ in
            model.refresh()
        }
        .alert(
            copy.removeRepositoryQuestion,
            isPresented: Binding(
                get: { repositoryToRemove != nil },
                set: { if !$0 { repositoryToRemove = nil } }
            ),
            presenting: repositoryToRemove
        ) { repository in
            Button(copy.remove, role: .destructive) {
                actionRunner.stop(actions: model.actions(for: repository.id), worktrees: repository.worktrees)
                model.removeRepository(repository)
                repositoryToRemove = nil
            }
            Button(copy.cancel, role: .cancel) {
                repositoryToRemove = nil
            }
        } message: { repository in
            Text(copy.stopTracking(repository.name))
        }
        .sheet(isPresented: $updates.isSheetPresented) {
            UpdateSheetView()
                .environmentObject(updates)
                .environment(\.atlasCopy, copy)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    @Binding var repositoryToRemove: RepositoryStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(copy.repositories)
                    .font(.system(size: RuntimeAtlasTheme.Typography.sectionTitle, weight: .semibold))
                if let count = model.status?.repositories.count {
                    Text("\(count)")
                        .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .semibold, design: .rounded))
                        .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                        .accessibilityLabel(copy.registeredRepositories(count))
                }
                Spacer(minLength: 8)
                Button {
                    model.chooseRepository()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .accessibilityLabel(copy.addRepository)
                .help(copy.addRepository)

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .disabled(model.isRefreshing)
                .accessibilityLabel(model.isRefreshing ? copy.refreshingAccessibility : copy.refreshAccessibility)
                .help(model.isRefreshing ? copy.refreshing : copy.refresh)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().overlay(RuntimeAtlasTheme.border)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let repositories = model.status?.repositories, !repositories.isEmpty {
                        ForEach(repositories) { repository in
                            RepositorySidebarSection(
                                repository: repository,
                                onRemove: { repositoryToRemove = repository }
                            )
                            .environmentObject(model)
                        }
                    } else if model.isRefreshing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(copy.readingLocalState)
                                .font(.system(size: RuntimeAtlasTheme.Typography.body))
                                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                        }
                        .padding(14)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(copy.noRepositories)
                                .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                            Text(copy.addRepositoryToDiscover)
                                .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .background(RuntimeAtlasTheme.sidebar)
    }
}

private struct RepositorySidebarSection: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let repository: RepositoryStatus
    let onRemove: () -> Void
    @State private var showingCommandSettings = false
    @State private var displayedWorktrees: [WorktreeStatus]
    @State private var draggedWorktreePath: String?

    init(repository: RepositoryStatus, onRemove: @escaping () -> Void) {
        self.repository = repository
        self.onRemove = onRemove
        _displayedWorktrees = State(initialValue: repository.worktrees)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: repository.availability == .available ? "externaldrive" : "externaldrive.badge.exclamationmark")
                    .foregroundStyle(
                        repository.availability == .available
                            ? RuntimeAtlasTheme.accent
                            : RuntimeAtlasTheme.amber
                    )
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(repository.name)
                        .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                        .lineLimit(1)
                    Text(repository.path)
                        .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                        .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .accessibilityLabel(copy.removeNamedRepository(repository.name))
                .help(copy.removeRepositoryHelp)
            }
            .padding(.horizontal, 12)

            Button {
                showingCommandSettings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                    Text(copy.configureActions)
                        .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .medium))
                    Spacer(minLength: 4)
                    Text("\(model.actions(for: repository.id).count)")
                        .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .semibold, design: .rounded))
                        .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(RuntimeAtlasTheme.control)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(RuntimeAtlasTheme.border)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .accessibilityLabel(copy.repositoryActionsFor(repository.name))

            if repository.availability == .unavailable {
                SidebarUnavailable(reason: repository.unavailableReason ?? copy.repositoryUnavailable)
                    .padding(.horizontal, 12)
            } else if repository.worktrees.isEmpty {
                Text(copy.noWorktreesFound)
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .padding(.horizontal, 12)
            } else {
                VStack(spacing: 3) {
                    ForEach(displayedWorktrees) { worktree in
                        WorktreeSidebarRow(
                            worktree: worktree,
                            selected: worktree.path == model.selectedWorktreePath,
                            action: { model.select(worktree: worktree) }
                        )
                        .onDrag {
                            draggedWorktreePath = worktree.path
                            return NSItemProvider(object: dragValue(for: worktree) as NSString)
                        } preview: {
                            WorktreeDragPreview(worktree: worktree)
                        }
                        .onDrop(
                            of: [.plainText],
                            delegate: WorktreeReorderDropDelegate(
                                targetPath: worktree.path,
                                worktrees: $displayedWorktrees,
                                draggedPath: $draggedWorktreePath,
                                commit: commitDisplayedOrder
                            )
                        )
                    }
                }
                .padding(.horizontal, 7)
            }
        }
        .sheet(isPresented: $showingCommandSettings) {
            ActionManagerView(repository: repository)
            .environmentObject(model)
            .environment(\.atlasCopy, copy)
        }
        .onChange(of: repository.worktrees) { refreshedWorktrees in
            draggedWorktreePath = nil
            displayedWorktrees = refreshedWorktrees
        }
    }

    private func dragValue(for worktree: WorktreeStatus) -> String {
        "runtime-atlas-worktree:\(worktree.path)"
    }

    private func commitDisplayedOrder() {
        draggedWorktreePath = nil
        if !model.saveWorktreeOrder(in: repository, worktrees: displayedWorktrees) {
            withAnimation(.easeOut(duration: 0.16)) {
                displayedWorktrees = repository.worktrees
            }
        }
    }
}

private struct WorktreeReorderDropDelegate: DropDelegate {
    let targetPath: String
    @Binding var worktrees: [WorktreeStatus]
    @Binding var draggedPath: String?
    let commit: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedPath,
              draggedPath != targetPath,
              let sourceIndex = worktrees.firstIndex(where: { $0.path == draggedPath }),
              let targetIndex = worktrees.firstIndex(where: { $0.path == targetPath }) else { return }

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
            let moved = worktrees.remove(at: sourceIndex)
            worktrees.insert(moved, at: targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        commit()
        return true
    }
}

private struct WorktreeDragPreview: View {
    let worktree: WorktreeStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(RuntimeAtlasTheme.accent)
            Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(RuntimeAtlasTheme.primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RuntimeAtlasTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(RuntimeAtlasTheme.accent.opacity(0.45))
        }
    }
}

private struct SidebarUnavailable: View {
    @Environment(\.atlasCopy) private var copy
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(copy.unavailable(reason))
        }
        .font(.system(size: RuntimeAtlasTheme.Typography.caption))
        .foregroundStyle(RuntimeAtlasTheme.amber)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private struct WorktreeSidebarRow: View {
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(selectionColor)
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                            .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .medium))
                            .lineLimit(1)
                        if worktree.dirty {
                            Circle()
                                .fill(RuntimeAtlasTheme.amber)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel(copy.dirtyWorktree)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(worktree.detached ? copy.detachedHead : (worktree.branch ?? copy.unknownBranch))
                            .lineLimit(1)
                        Text(worktree.shortSHA)
                            .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                    }
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                }
                Spacer(minLength: 2)
                if worktree.availability == .unavailable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: RuntimeAtlasTheme.Typography.caption))
                        .foregroundStyle(RuntimeAtlasTheme.amber)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? RuntimeAtlasTheme.selected : Color.clear)
            }
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(RuntimeAtlasTheme.accent.opacity(0.20))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectionColor: Color {
        if worktree.availability == .unavailable { return RuntimeAtlasTheme.amber }
        return selected ? RuntimeAtlasTheme.accent : RuntimeAtlasTheme.slate.opacity(0.45)
    }

    private var accessibilityText: String {
        let branch = worktree.detached ? copy.detachedHead : (worktree.branch ?? copy.unknownBranch)
        let dirty = worktree.dirty ? copy.dirty : copy.clean
        return "\(URL(fileURLWithPath: worktree.path).lastPathComponent), \(branch), \(worktree.shortSHA), \(dirty)"
    }
}

private struct DetailPane: View {
    @EnvironmentObject private var model: AtlasAppModel

    var body: some View {
        Group {
            if let worktree = model.selectedWorktree {
                WorktreeDetailView(worktree: worktree)
                    .environmentObject(model)
            } else {
                EmptyDetailView(hasRepositories: !(model.status?.repositories.isEmpty ?? true))
                    .environmentObject(model)
            }
        }
        .background(RuntimeAtlasTheme.background)
    }
}

private struct EmptyDetailView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let hasRepositories: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasRepositories ? "externaldrive.badge.exclamationmark" : "point.3.connected.trianglepath.dotted")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(hasRepositories ? RuntimeAtlasTheme.amber : RuntimeAtlasTheme.accent)
            Text(hasRepositories ? copy.noAvailableWorktree : copy.buildRuntimeMap)
                .font(.system(size: 24, weight: .semibold))
            Text(
                hasRepositories
                    ? copy.reviewUnavailableMessage
                    : copy.addRepositoryEmptyDescription
            )
            .font(.system(size: 15))
            .foregroundStyle(RuntimeAtlasTheme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 430)

            if !hasRepositories {
                Button {
                    model.chooseRepository()
                } label: {
                    Label(copy.addRepository, systemImage: "folder.badge.plus")
                }
                .buttonStyle(AtlasButtonStyle(prominent: true))
            }

            if let message = model.operationMessage {
                Text(message)
                    .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                    .foregroundStyle(RuntimeAtlasTheme.amber)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
