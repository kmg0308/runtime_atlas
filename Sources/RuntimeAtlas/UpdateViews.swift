import RuntimeAtlasCore
import SwiftUI

struct UpdateAvailableBanner: View {
    @EnvironmentObject private var updates: UpdateModel
    @Environment(\.atlasCopy) private var copy

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RuntimeAtlasTheme.accent)
                .accessibilityHidden(true)

            Text(updates.statusText(copy: copy))
                .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .medium))
                .foregroundStyle(RuntimeAtlasTheme.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if updates.buttonsDisabled {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(copy.updateInProgress)
            }

            Button(updateButtonTitle) {
                updates.updateNow()
            }
            .buttonStyle(AtlasButtonStyle(prominent: true))
            .disabled(updates.buttonsDisabled)
            .accessibilityHint(copy.updateInstallHint)

            Button(copy.updateDetails) {
                updates.isSheetPresented = true
            }
            .buttonStyle(AtlasButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .atlasSurface(elevated: true)
        .accessibilityElement(children: .contain)
    }

    private var updateButtonTitle: String {
        if updates.isInstalling {
            return copy.installingEllipsis
        }
        if updates.isDownloading {
            return copy.updatingEllipsis
        }
        return copy.updateNow
    }
}

struct UpdateSheetView: View {
    @EnvironmentObject private var updates: UpdateModel
    @Environment(\.atlasCopy) private var copy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.updates)
                        .font(.system(size: RuntimeAtlasTheme.Typography.modalTitle, weight: .semibold))
                        .foregroundStyle(RuntimeAtlasTheme.primaryText)
                    Text(statusTitle)
                        .font(.system(size: RuntimeAtlasTheme.Typography.secondary, weight: .medium))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: RuntimeAtlasTheme.Typography.body, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                .accessibilityLabel(copy.close)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    versionColumn(copy.currentVersion, UpdateService.installedVersion())
                    Rectangle()
                        .fill(RuntimeAtlasTheme.border)
                        .frame(width: 1, height: 42)
                    versionColumn(copy.availableVersion, availableVersionText)
                }

                Divider().overlay(RuntimeAtlasTheme.border)

                Text(updates.statusText(copy: copy))
                    .font(.system(size: RuntimeAtlasTheme.Typography.secondary))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(copy.updateSigningNotice)
                    .font(.system(size: RuntimeAtlasTheme.Typography.caption))
                    .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .atlasSurface()

            HStack(spacing: 10) {
                if updates.buttonsDisabled {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(copy.updateInProgress)
                }

                Button(copy.checkForUpdates) {
                    updates.checkLatestRelease(silent: false)
                }
                .buttonStyle(AtlasButtonStyle())
                .disabled(updates.buttonsDisabled)

                Spacer()

                if updates.isUpdateAvailable {
                    Button(copy.installAndRelaunch) {
                        updates.updateNow()
                    }
                    .buttonStyle(AtlasButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(updates.buttonsDisabled)
                    .accessibilityHint(copy.updateInstallHint)
                }
            }
        }
        .padding(24)
        .frame(width: 540)
        .foregroundStyle(RuntimeAtlasTheme.primaryText)
        .background(RuntimeAtlasTheme.background)
        .onAppear {
            updates.checkIfConfigured(silent: true)
        }
    }

    private var statusTitle: String {
        if updates.isInstalling {
            return copy.installing
        }
        if updates.downloadedFileIsInstallable {
            return copy.readyToInstall
        }
        if updates.isUpdateAvailable {
            return copy.updateAvailableTitle
        }
        if case .failed = updates.status {
            return copy.updateCheckFailed
        }
        if updates.availability != nil {
            return copy.upToDate
        }
        return copy.notChecked
    }

    private var availableVersionText: String {
        guard let availability = updates.availability else {
            return copy.notChecked
        }
        return availability.isAvailable ? availability.release.version : copy.noUpdate
    }

    private var statusColor: Color {
        if case .failed = updates.status {
            return RuntimeAtlasTheme.red
        }
        return updates.isUpdateAvailable
            ? RuntimeAtlasTheme.accent
            : RuntimeAtlasTheme.secondaryText
    }

    private func versionColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: RuntimeAtlasTheme.Typography.caption, weight: .medium))
                .foregroundStyle(RuntimeAtlasTheme.secondaryText)
            Text(value)
                .font(.system(size: RuntimeAtlasTheme.Typography.sectionTitle, weight: .semibold))
                .foregroundStyle(RuntimeAtlasTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
