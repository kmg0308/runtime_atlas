import Foundation
import RuntimeAtlasCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @EnvironmentObject private var updates: UpdateModel
    @Environment(\.atlasCopy) private var copy
    @State private var repositoryToRemove: RepositoryStatus?

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if updates.isUpdateAvailable {
                UpdateAvailableBanner()
                    .environmentObject(updates)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }

            HSplitView {
                SidebarView(repositoryToRemove: $repositoryToRemove)
                    .environmentObject(model)
                    .frame(minWidth: 250, idealWidth: 286, maxWidth: 350)

                DetailPane()
                    .environmentObject(model)
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(RuntimeAtlasTheme.primaryText)
        .background(RuntimeAtlasTheme.background)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.chooseRepository()
                } label: {
                    Label(copy.addRepository, systemImage: "folder.badge.plus")
                }
                .accessibilityLabel(copy.addRepository)

                Button {
                    model.refresh()
                } label: {
                    if model.isRefreshing {
                        Label(copy.refreshing, systemImage: "arrow.clockwise")
                    } else {
                        Label(copy.refresh, systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing)
                .accessibilityLabel(model.isRefreshing ? copy.refreshingAccessibility : copy.refreshAccessibility)
            }
        }
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
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let count = model.status?.repositories.count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                        .accessibilityLabel(copy.registeredRepositories(count))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
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
                                .font(.system(size: 12))
                                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                        }
                        .padding(14)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(copy.noRepositories)
                                .font(.system(size: 12, weight: .semibold))
                            Text(copy.addRepositoryToDiscover)
                                .font(.system(size: 11))
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
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(repository.path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .accessibilityLabel(copy.removeNamedRepository(repository.name))
                .help(copy.removeRepositoryHelp)
            }
            .padding(.horizontal, 12)

            if repository.availability == .unavailable {
                SidebarUnavailable(reason: repository.unavailableReason ?? copy.repositoryUnavailable)
                    .padding(.horizontal, 12)
            } else if repository.worktrees.isEmpty {
                Text(copy.noWorktreesFound)
                    .font(.system(size: 10))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .padding(.horizontal, 12)
            } else {
                VStack(spacing: 3) {
                    ForEach(repository.worktrees) { worktree in
                        WorktreeSidebarRow(
                            worktree: worktree,
                            selected: worktree.path == model.selectedWorktreePath,
                            action: { model.select(worktree: worktree) }
                        )
                    }
                }
                .padding(.horizontal, 7)
            }
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
        .font(.system(size: 10))
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
                    .frame(width: 3, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        if worktree.dirty {
                            Circle()
                                .fill(RuntimeAtlasTheme.amber)
                                .frame(width: 6, height: 6)
                                .accessibilityLabel(copy.dirtyWorktree)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(worktree.detached ? copy.detachedHead : (worktree.branch ?? copy.unknownBranch))
                            .lineLimit(1)
                        Text(worktree.shortSHA)
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                }
                Spacer(minLength: 2)
                if worktree.availability == .unavailable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(RuntimeAtlasTheme.amber)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
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
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(hasRepositories ? RuntimeAtlasTheme.amber : RuntimeAtlasTheme.accent)
            Text(hasRepositories ? copy.noAvailableWorktree : copy.buildRuntimeMap)
                .font(.system(size: 20, weight: .semibold))
            Text(
                hasRepositories
                    ? copy.reviewUnavailableMessage
                    : copy.addRepositoryEmptyDescription
            )
            .font(.system(size: 13))
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
                    .font(.system(size: 11))
                    .foregroundStyle(RuntimeAtlasTheme.amber)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
