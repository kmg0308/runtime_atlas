import Foundation
import RuntimeAtlasCore
import SwiftUI

struct WorktreeDetailView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                detailHeader

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

                SectionCard(
                    title: copy.code,
                    subtitle: copy.codeSubtitle
                ) {
                    CodeSection(worktree: worktree)
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

                SectionCard(
                    title: copy.evidence,
                    subtitle: copy.evidenceSubtitle
                ) {
                    EvidenceSection(worktree: worktree)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 1_100, alignment: .leading)
        }
        .background(RuntimeAtlasTheme.background)
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(RuntimeAtlasTheme.selected)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(RuntimeAtlasTheme.accent.opacity(0.28))
                    }
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(RuntimeAtlasTheme.accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 5) {
                Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                    .font(.system(size: 21, weight: .semibold))
                Text(worktree.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            HStack(spacing: 7) {
                AtlasBadge(
                    text: worktree.detached ? copy.detachedBadge : (worktree.branch ?? copy.noBranchBadge),
                    icon: "arrow.triangle.branch",
                    color: RuntimeAtlasTheme.accent
                )
                AtlasBadge(
                    text: worktree.dirty ? copy.dirtyBadge : copy.cleanBadge,
                    icon: worktree.dirty ? "circle.dotted" : "checkmark.circle.fill",
                    color: worktree.dirty ? RuntimeAtlasTheme.amber : RuntimeAtlasTheme.mint
                )
            }
        }
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
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider().overlay(RuntimeAtlasTheme.border)

            content()
                .padding(16)
        }
        .atlasSurface()
    }
}

private struct CodeSection: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus
    @State private var databaseLabel = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if worktree.availability == .unavailable {
                InlineNotice(
                    icon: "exclamationmark.triangle.fill",
                    title: copy.worktreeUnavailable,
                    message: copy.localizedCoreMessage(worktree.unavailableReason ?? copy.gitCouldNotInspectWorktree),
                    color: RuntimeAtlasTheme.amber
                )
            }

            VStack(spacing: 0) {
                MetadataRow(label: copy.branch, value: worktree.detached ? copy.detachedHead : (worktree.branch ?? copy.unknown))
                Divider().overlay(RuntimeAtlasTheme.border)
                MetadataRow(label: copy.fullSHA, value: worktree.sha, monospaced: true)
                Divider().overlay(RuntimeAtlasTheme.border)
                MetadataRow(label: copy.workingTree, value: worktree.dirty ? copy.dirtyWorkingTree : copy.cleanWorkingTree)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(RuntimeAtlasTheme.border)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.logicalDBLabel)
                            .font(.system(size: 11, weight: .semibold))
                        Text(copy.logicalDBDescription)
                            .font(.system(size: 9))
                            .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    TextField(copy.logicalDBPlaceholder, text: $databaseLabel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: RuntimeAtlasTheme.controlRadius, style: .continuous)
                                .fill(RuntimeAtlasTheme.control)
                                .overlay {
                                    RoundedRectangle(cornerRadius: RuntimeAtlasTheme.controlRadius, style: .continuous)
                                        .stroke(RuntimeAtlasTheme.border)
                                }
                        }
                        .accessibilityLabel(copy.logicalDBLabel)

                    Button(copy.save) {
                        _ = model.saveDatabaseLabel(databaseLabel, for: worktree)
                    }
                    .buttonStyle(AtlasButtonStyle(prominent: true))
                    .accessibilityLabel(copy.saveLogicalDBLabel)
                }
            }
        }
        .onAppear {
            databaseLabel = worktree.databaseLabel ?? ""
        }
        .onChange(of: worktree.databaseLabel) { value in
            databaseLabel = value ?? ""
        }
        .onChange(of: worktree.path) { _ in
            databaseLabel = worktree.databaseLabel ?? ""
        }
    }
}

private struct MetadataRow: View {
    @Environment(\.atlasCopy) private var copy
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .frame(width: 95, alignment: .leading)
            Text(value.isEmpty ? copy.unavailableValue : value)
                .font(.system(size: 11, design: monospaced ? .monospaced : .default))
                .foregroundStyle(value.isEmpty ? RuntimeAtlasTheme.amber : RuntimeAtlasTheme.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

private struct RuntimeMapSection: View {
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus
    let processDiscovery: DiscoveryAvailability
    let dockerDiscovery: DiscoveryAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RuntimeRailRow(
                icon: "arrow.triangle.branch",
                title: URL(fileURLWithPath: worktree.path).lastPathComponent,
                detail: worktree.detached ? copy.detachedAt(worktree.shortSHA) : "\(worktree.branch ?? copy.unknownBranch) @ \(worktree.shortSHA)",
                color: RuntimeAtlasTheme.accent,
                badges: worktree.databaseLabel.map { ["DB  \($0)"] } ?? []
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
                        detail: "PID \(process.pid)  ·  \(process.cwd ?? copy.cwdUnavailable)",
                        color: RuntimeAtlasTheme.mint,
                        badges: process.ports.map { "\($0.address):\($0.port)" }
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
                        badges: container.ports.map {
                            "\($0.hostIP.isEmpty ? "*" : $0.hostIP):\($0.hostPort) → \($0.containerPort)/\($0.transport)"
                        }
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
    }
}

private struct RuntimeRailRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    let badges: [String]

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(RuntimeAtlasTheme.surface)
                    .overlay(Circle().stroke(color.opacity(0.82), lineWidth: 1.5))
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 25, height: 25)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(detail)
                    .font(.system(size: 9, design: detail.contains("/") ? .monospaced : .default))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 10)

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                            PortChip(text: badge, color: color)
                        }
                    }
                }
                .frame(maxWidth: 300)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct PortChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
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

private struct EvidenceSection: View {
    @Environment(\.atlasCopy) private var copy
    let worktree: WorktreeStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                EvidenceCountBadge(status: .pass, count: worktree.evidence.currentCounts.pass)
                EvidenceCountBadge(status: .fail, count: worktree.evidence.currentCounts.fail)
                EvidenceCountBadge(status: .blocked, count: worktree.evidence.currentCounts.blocked)
                EvidenceCountBadge(status: .pending, count: worktree.evidence.currentCounts.pending)
                Spacer()
                Text(copy.currentSHA)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
            }

            if let latest = worktree.evidence.latestCurrent {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.latestCurrentEvidence)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    EvidenceRow(evidence: latest, currentSHA: worktree.sha)
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(RuntimeAtlasTheme.control.opacity(0.70))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(RuntimeAtlasTheme.border)
                        }
                }
            } else {
                InlineNotice(
                    icon: "checkmark.seal",
                    title: copy.noCurrentEvidence,
                    message: copy.runEvidenceCommand,
                    color: RuntimeAtlasTheme.slate
                )
            }

            Divider().overlay(RuntimeAtlasTheme.border)

            VStack(alignment: .leading, spacing: 9) {
                Text(copy.history)
                    .font(.system(size: 11, weight: .semibold))

                if worktree.evidence.history.isEmpty {
                    Text(copy.noEvidenceHistory)
                        .font(.system(size: 10))
                        .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                        .padding(.vertical, 4)
                } else {
                    ForEach(worktree.evidence.history) { evidence in
                        EvidenceRow(evidence: evidence, currentSHA: worktree.sha)
                        if evidence.id != worktree.evidence.history.last?.id {
                            Divider().overlay(RuntimeAtlasTheme.border)
                        }
                    }
                }
            }
        }
    }
}

private struct EvidenceCountBadge: View {
    @Environment(\.atlasCopy) private var copy
    let status: EvidenceDisplayStatus
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.rawValue)
            Text("\(count)")
                .fontWeight(.bold)
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(status.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(status.color.opacity(0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(status.color.opacity(0.24))
                }
        }
        .accessibilityLabel(copy.currentSHARecordCount(status: status, count: count))
    }
}

private struct EvidenceRow: View {
    @Environment(\.atlasCopy) private var copy
    let evidence: EvidencePresentation
    let currentSHA: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AtlasBadge(
                text: evidence.displayStatus.rawValue,
                icon: evidence.displayStatus.icon,
                color: evidence.displayStatus.color
            )
            .frame(width: 92, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(copy.evidenceKind(evidence.record.kind))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    Text(copy.format(evidence.record.endedAt))
                        .font(.system(size: 9))
                        .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    if let exitCode = evidence.record.exitCode {
                        Text(copy.exitCode(exitCode))
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(exitCode == 0 ? RuntimeAtlasTheme.mint : RuntimeAtlasTheme.red)
                    }
                }

                if let command = evidence.record.command {
                    Text(command.joined(separator: " "))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(RuntimeAtlasTheme.primaryText)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                if let note = evidence.record.note {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(RuntimeAtlasTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    Text(String(evidence.record.sha.prefix(7)))
                        .font(.system(size: 8, design: .monospaced))
                    Text(evidence.record.dirty ? copy.dirtyAtRecordTime : copy.cleanAtRecordTime)
                    if let viewport = evidence.record.viewport {
                        Text(copy.viewport(viewport))
                    }
                    if evidence.displayStatus == .stale {
                        Text(copy.wasStatus(evidence.record.status))
                            .foregroundStyle(evidence.record.status.displayColor)
                    }
                }
                .font(.system(size: 8))
                .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(evidenceAccessibilityLabel)
    }

    private var evidenceAccessibilityLabel: String {
        copy.evidenceAccessibility(evidence)
    }
}

private struct InlineNotice: View {
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
                    .font(.system(size: 10, weight: .semibold))
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
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

private struct AtlasBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
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

private extension EvidenceDisplayStatus {
    var color: Color {
        switch self {
        case .pass: RuntimeAtlasTheme.mint
        case .fail: RuntimeAtlasTheme.red
        case .blocked: RuntimeAtlasTheme.amber
        case .pending: RuntimeAtlasTheme.slate
        case .stale: RuntimeAtlasTheme.accent
        }
    }

    var icon: String {
        switch self {
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .blocked: "exclamationmark.octagon.fill"
        case .pending: "clock.fill"
        case .stale: "arrow.triangle.2.circlepath"
        }
    }
}

private extension EvidenceStatus {
    var displayColor: Color {
        switch self {
        case .pass: RuntimeAtlasTheme.mint
        case .fail: RuntimeAtlasTheme.red
        case .blocked: RuntimeAtlasTheme.amber
        case .pending: RuntimeAtlasTheme.slate
        }
    }
}
