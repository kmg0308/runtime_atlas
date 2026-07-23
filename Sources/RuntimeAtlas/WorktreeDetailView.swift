import Foundation
import RuntimeAtlasCore
import SwiftUI

struct WorktreeDetailView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                detailHeader

                if worktree.availability == .unavailable {
                    InlineNotice(
                        icon: "exclamationmark.triangle.fill",
                        title: copy.worktreeUnavailable,
                        message: copy.localizedCoreMessage(worktree.unavailableReason ?? copy.gitCouldNotInspectWorktree),
                        color: RuntimeAtlasTheme.amber
                    )
                }

                if let message = model.operationMessage {
                    InlineNotice(
                        icon: "info.circle.fill",
                        title: copy.appName,
                        message: message,
                        color: RuntimeAtlasTheme.accent
                    )
                }

                if let notices = model.status?.notices, !notices.isEmpty {
                    ForEach(Array(notices.enumerated()), id: \.offset) { _, notice in
                        InlineNotice(
                            icon: "exclamationmark.triangle.fill",
                            title: notice.kind == .error ? copy.localDataIssue : copy.notice,
                            message: copy.localizedCoreMessage(notice.message),
                            color: notice.kind == .error ? RuntimeAtlasTheme.red : RuntimeAtlasTheme.amber
                        )
                    }
                }

                if let repository = model.selectedRepository,
                   !model.actions(for: repository.id).isEmpty {
                    WorktreeCommandsSection(repository: repository, worktree: worktree)
                        .environmentObject(model)
                }

                SectionCard(
                    title: copy.runtimeMap,
                    subtitle: copy.runtimeMapSubtitle
                ) {
                    RuntimeMapSection(
                        worktree: worktree,
                        processDiscovery: model.status?.processDiscovery ?? .available,
                        dockerDiscovery: model.status?.dockerDiscovery ?? .available
                    )
                }

            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: 1_200, alignment: .leading)
        }
        .background(RuntimeAtlasTheme.background)
    }

    private var detailHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                headerIdentity
                Spacer(minLength: 12)
                headerBadges
            }

            VStack(alignment: .leading, spacing: 12) {
                headerIdentity
                headerBadges
            }
        }
    }

    private var headerIdentity: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(RuntimeAtlasTheme.selected)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(RuntimeAtlasTheme.accent.opacity(0.28))
                    }
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(RuntimeAtlasTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                    .font(.system(size: RuntimeAtlasTheme.Typography.screenTitle, weight: .semibold))
                Text(worktree.path)
                    .font(.system(size: RuntimeAtlasTheme.Typography.technical, design: .monospaced))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    private var headerBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                branchBadge
                dirtyBadge
                shaBadge
            }
            VStack(alignment: .leading, spacing: 7) {
                branchBadge
                HStack(spacing: 7) {
                    dirtyBadge
                    shaBadge
                }
            }
        }
    }

    private var branchBadge: some View {
        AtlasBadge(
            text: worktree.detached ? copy.detachedBadge : (worktree.branch ?? copy.noBranchBadge),
            icon: "arrow.triangle.branch",
            color: RuntimeAtlasTheme.accent
        )
    }

    private var dirtyBadge: some View {
        AtlasBadge(
            text: worktree.dirty ? copy.dirtyBadge : copy.cleanBadge,
            icon: worktree.dirty ? "circle.dotted" : "checkmark.circle.fill",
            color: worktree.dirty ? RuntimeAtlasTheme.amber : RuntimeAtlasTheme.mint
        )
    }

    private var shaBadge: some View {
        AtlasBadge(
            text: worktree.shortSHA.isEmpty ? copy.unavailableValue : worktree.shortSHA,
            icon: "number",
            color: RuntimeAtlasTheme.slate
        )
        .help(worktree.sha)
        .accessibilityLabel("\(copy.fullSHA), \(worktree.sha)")
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: RuntimeAtlasTheme.Typography.sectionTitle, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider().overlay(RuntimeAtlasTheme.border)

            content()
                .padding(18)
        }
        .atlasSurface()
    }
}

private struct RuntimeMapSection: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus
    let processDiscovery: DiscoveryAvailability
    let dockerDiscovery: DiscoveryAvailability
    @State private var processToStop: RuntimeProcess?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RuntimeRailRow(
                icon: "arrow.triangle.branch",
                title: URL(fileURLWithPath: worktree.path).lastPathComponent,
                detail: worktree.detached ? copy.detachedAt(worktree.shortSHA) : "\(worktree.branch ?? copy.unknownBranch) @ \(worktree.shortSHA)",
                color: RuntimeAtlasTheme.accent,
                badges: []
            )

            if processDiscovery.state == .unavailable {
                RuntimeRailRow(
                    icon: "exclamationmark.triangle.fill",
                    title: copy.processesUnavailable,
                    detail: copy.localizedCoreMessage(processDiscovery.reason ?? copy.listeningPortsUnreadable),
                    color: RuntimeAtlasTheme.amber,
                    badges: []
                )
            } else if worktree.processes.isEmpty {
                RuntimeRailRow(
                    icon: "terminal",
                    title: copy.noMappedListeningProcess,
                    detail: copy.noListenProcessInWorktree,
                    color: RuntimeAtlasTheme.slate,
                    badges: []
                )
            } else {
                ForEach(worktree.processes) { process in
                    RuntimeRailRow(
                        icon: "terminal.fill",
                        title: copy.localizedCoreMessage(process.name),
                        detail: copy.processLocation(pid: process.pid, cwd: process.cwd),
                        color: RuntimeAtlasTheme.mint,
                        badges: process.ports.map { "\($0.address):\($0.port)" },
                        actionTitle: copy.closePorts,
                        actionAccessibilityLabel: "\(copy.closePorts), \(process.name), PID \(process.pid)",
                        action: { processToStop = process }
                    )
                }
            }

            if dockerDiscovery.state == .unavailable {
                RuntimeRailRow(
                    icon: "shippingbox.fill",
                    title: copy.dockerUnavailable,
                    detail: copy.localizedCoreMessage(dockerDiscovery.reason ?? copy.dockerCouldNotBeRead),
                    color: RuntimeAtlasTheme.amber,
                    badges: [copy.unavailableBadge]
                )
            } else if worktree.containers.isEmpty {
                RuntimeRailRow(
                    icon: "shippingbox",
                    title: copy.noMappedRunningContainer,
                    detail: copy.dockerAvailableNoMount,
                    color: RuntimeAtlasTheme.slate,
                    badges: [copy.dockerAvailableBadge]
                )
            } else {
                ForEach(worktree.containers) { container in
                    RuntimeRailRow(
                        icon: "shippingbox.fill",
                        title: copy.localizedCoreMessage(container.name),
                        detail: copy.localizedCoreMessage(container.image),
                        color: RuntimeAtlasTheme.accent,
                        badges: portBadges(container.ports)
                    )
                }
            }
        }
        .background(alignment: .leading) {
            Rectangle()
                .fill(RuntimeAtlasTheme.accent.opacity(0.22))
                .frame(width: 1)
                .padding(.leading, 12)
                .padding(.vertical, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.runtimeMapAccessibility(URL(fileURLWithPath: worktree.path).lastPathComponent))
        .alert(
            copy.closePortsQuestion,
            isPresented: Binding(
                get: { processToStop != nil },
                set: { if !$0 { processToStop = nil } }
            ),
            presenting: processToStop
        ) { process in
            Button(copy.stopProcess, role: .destructive) {
                model.stopListeningProcess(process, in: worktree)
                processToStop = nil
            }
            Button(copy.cancel, role: .cancel) { processToStop = nil }
        } message: { process in
            Text(
                copy.processStopWarning(
                    name: process.name,
                    pid: process.pid,
                    ports: process.ports.map { "\($0.address):\($0.port)" }.joined(separator: ", ")
                )
            )
        }
    }

    private func portBadges(_ ports: [PublishedPort]) -> [String] {
        Dictionary(grouping: ports) { port in
            "\(port.hostPort)|\(port.containerPort)|\(port.transport)"
        }
        .values
        .sorted { lhs, rhs in
            guard let left = lhs.first, let right = rhs.first else { return lhs.count < rhs.count }
            if left.hostPort != right.hostPort { return left.hostPort < right.hostPort }
            if left.containerPort != right.containerPort { return left.containerPort < right.containerPort }
            return left.transport < right.transport
        }
        .compactMap { group in
            guard let port = group.first else { return nil }
            let host = group.count > 1 || port.hostIP.isEmpty ? "*" : port.hostIP
            return "\(host):\(port.hostPort) → \(port.containerPort)/\(port.transport)"
        }
    }
}

private struct RuntimeRailRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    let badges: [String]
    let actionTitle: String?
    let actionAccessibilityLabel: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        detail: String,
        color: Color,
        badges: [String],
        actionTitle: String? = nil,
        actionAccessibilityLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.color = color
        self.badges = badges
        self.actionTitle = actionTitle
        self.actionAccessibilityLabel = actionAccessibilityLabel
        self.action = action
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                railContent
                Spacer(minLength: 10)
                accessories.frame(maxWidth: 380)
            }
            VStack(alignment: .leading, spacing: 7) {
                railContent
                if !badges.isEmpty || action != nil {
                    accessories.padding(.leading, 44)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: action == nil ? .combine : .contain)
    }

    private var railContent: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(RuntimeAtlasTheme.surface)
                    .overlay(Circle().stroke(color.opacity(0.82), lineWidth: 1.5))
                Image(systemName: icon)
                    .font(.system(size: RuntimeAtlasTheme.Typography.badge, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                Text(detail)
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption, design: detail.contains("/") ? .monospaced : .default))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private var badgeStrip: some View {
        if !badges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                        PortChip(text: badge, color: color)
                    }
                }
            }
        }
    }

    private var accessories: some View {
        HStack(spacing: 7) {
            badgeStrip
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "xmark.circle")
                        .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .semibold))
                        .foregroundStyle(RuntimeAtlasTheme.red)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(RuntimeAtlasTheme.control)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(RuntimeAtlasTheme.red.opacity(0.34))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
            }
        }
    }
}

private struct PortChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: RuntimeAtlasTheme.Typography.badge, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.09))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(color.opacity(0.25))
                    }
            }
    }
}

struct InlineNotice: View {
    let icon: String
    let title: String
    let message: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .semibold))
                Text(message)
                    .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(color.opacity(0.22))
                }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AtlasBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: RuntimeAtlasTheme.Typography.badge, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.opacity(0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(color.opacity(0.24))
                }
        }
        .accessibilityElement(children: .combine)
    }
}
