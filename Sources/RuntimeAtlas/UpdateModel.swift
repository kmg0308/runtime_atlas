import AppKit
import Foundation
import RuntimeAtlasCore
import SwiftUI

enum UpdateStatus {
    case ready
    case checking
    case available(String)
    case upToDate(Date)
    case downloading(String)
    case installing(String)
    case installingAndRelaunching
    case failed(UpdateFailure)
}

enum UpdateFailure {
    case invalidResponse
    case untrustedDownloadURL
    case noDownloadURL
    case noDownloadedFile
    case notAnAppBundle
    case invalidDownloadedArchive(String)
    case invalidDownloadedAppBundle(String)
    case invalidCodeSignature(String)
    case network
    case unexpected

    init(_ error: Error) {
        switch error {
        case UpdateServiceError.invalidResponse:
            self = .invalidResponse
        case UpdateServiceError.untrustedDownloadURL:
            self = .untrustedDownloadURL
        case UpdateServiceError.noDownloadURL:
            self = .noDownloadURL
        case UpdateServiceError.noDownloadedFile:
            self = .noDownloadedFile
        case UpdateServiceError.notAnAppBundle:
            self = .notAnAppBundle
        case UpdateServiceError.invalidDownloadedArchive(let detail):
            self = .invalidDownloadedArchive(detail)
        case UpdateServiceError.invalidDownloadedAppBundle(let detail):
            self = .invalidDownloadedAppBundle(detail)
        case UpdateServiceError.invalidCodeSignature(let detail):
            self = .invalidCodeSignature(detail)
        case is URLError:
            self = .network
        default:
            self = .unexpected
        }
    }
}

@MainActor
final class UpdateModel: ObservableObject {
    @Published private(set) var availability: UpdateAvailability?
    @Published private(set) var status: UpdateStatus = .ready
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isInstalling = false
    @Published private(set) var downloadedFile: URL?
    @Published private(set) var downloadedFileIsInstallable = false
    @Published var isSheetPresented = false

    private static let autoCheckIntervalNanoseconds: UInt64 = 21_600_000_000_000
    private var autoCheckTask: Task<Void, Never>?
    private var downloadedReleaseIdentity: String?

    var isUpdateAvailable: Bool {
        availability?.isAvailable == true || downloadedFileIsInstallable
    }

    var buttonsDisabled: Bool {
        isChecking || isDownloading || isInstalling
    }

    deinit {
        autoCheckTask?.cancel()
    }

    func updateLabel(copy: AtlasCopy) -> String? {
        guard let availability, availability.isAvailable else { return nil }
        return copy.updateVersionLabel(availability.release.version)
    }

    func statusText(copy: AtlasCopy) -> String {
        switch status {
        case .ready:
            return copy.updateReady
        case .checking:
            return copy.checkingLatestRelease
        case .available(let version):
            return copy.updateAvailable(version)
        case .upToDate(let date):
            return copy.upToDateChecked(at: date)
        case .downloading(let version):
            return copy.downloadingVersion(version)
        case .installing(let version):
            return copy.installingVersion(version)
        case .installingAndRelaunching:
            return copy.installingAndRelaunching
        case .failed(let failure):
            return failure.localizedDescription(copy: copy)
        }
    }

    func checkIfConfigured(silent: Bool = false) {
        checkLatestRelease(silent: silent)
    }

    func startAutoChecks() {
        guard autoCheckTask == nil else { return }

        autoCheckTask = Task { @MainActor [weak self] in
            self?.checkIfConfigured(silent: true)

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.autoCheckIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                self?.checkIfConfigured(silent: true)
            }
        }
    }

    func checkLatestRelease(silent: Bool = false) {
        guard !buttonsDisabled else { return }

        isChecking = true
        status = .checking
        if !silent {
            isSheetPresented = true
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await UpdateService.checkLatestRelease()
                availability = result
                clearStaleDownloadedUpdate(for: result)
                status = result.isAvailable
                    ? .available(result.release.version)
                    : .upToDate(Date())
            } catch {
                status = .failed(UpdateFailure(error))
            }
            isChecking = false
        }
    }

    func updateNow() {
        if downloadedFileIsInstallable {
            installDownloadedUpdate()
            return
        }

        if let release = availability?.release, availability?.isAvailable == true {
            downloadAndInstall(release: release)
            return
        }

        checkAndInstallLatestRelease()
    }

    func installDownloadedUpdate() {
        guard !isInstalling else { return }
        guard let downloadedFile,
              FileManager.default.fileExists(atPath: downloadedFile.path) else {
            clearDownloadedUpdate()
            status = .failed(.noDownloadedFile)
            isSheetPresented = true
            return
        }

        isInstalling = true
        isSheetPresented = true
        status = .installingAndRelaunching
        Task { @MainActor [weak self] in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try UpdateService.installDownloadedAppArchive(downloadedFile)
                }.value
                NSApp.terminate(nil)
            } catch {
                self?.status = .failed(UpdateFailure(error))
                self?.isInstalling = false
                self?.isSheetPresented = true
            }
        }
    }

    private func checkAndInstallLatestRelease() {
        guard !buttonsDisabled else { return }

        isChecking = true
        status = .checking
        isSheetPresented = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await UpdateService.checkLatestRelease()
                availability = result
                clearStaleDownloadedUpdate(for: result)
                isChecking = false

                if result.isAvailable {
                    downloadAndInstall(release: result.release)
                } else {
                    status = .upToDate(Date())
                }
            } catch {
                status = .failed(UpdateFailure(error))
                isChecking = false
            }
        }
    }

    private func downloadAndInstall(release: ReleaseInfo) {
        guard !isDownloading, !isInstalling else { return }
        isDownloading = true
        isSheetPresented = true
        status = .downloading(release.version)
        Task { [weak self] in
            guard let self else { return }
            do {
                downloadedFile = try await UpdateService.downloadRelease(release)
                downloadedFileIsInstallable = true
                downloadedReleaseIdentity = release.downloadIdentity
                status = .installing(release.version)
                isDownloading = false
                installDownloadedUpdate()
            } catch {
                status = .failed(UpdateFailure(error))
                isDownloading = false
            }
        }
    }

    private func clearStaleDownloadedUpdate(for availability: UpdateAvailability) {
        guard downloadedFileIsInstallable else { return }
        guard availability.isAvailable,
              downloadedReleaseIdentity == availability.release.downloadIdentity,
              let downloadedFile,
              FileManager.default.fileExists(atPath: downloadedFile.path) else {
            clearDownloadedUpdate()
            return
        }
    }

    private func clearDownloadedUpdate() {
        downloadedFile = nil
        downloadedFileIsInstallable = false
        downloadedReleaseIdentity = nil
    }
}

private extension UpdateFailure {
    func localizedDescription(copy: AtlasCopy) -> String {
        switch self {
        case .invalidResponse:
            return copy.updateInvalidResponse
        case .untrustedDownloadURL:
            return copy.updateUntrustedDownloadURL
        case .noDownloadURL:
            return copy.updateNoDownloadURL
        case .noDownloadedFile:
            return copy.updateNoDownloadedFile
        case .notAnAppBundle:
            return copy.updateNotPackagedApp
        case .invalidDownloadedArchive(let detail):
            return copy.updateInvalidArchive(detail)
        case .invalidDownloadedAppBundle(let detail):
            return copy.updateInvalidBundle(detail)
        case .invalidCodeSignature(let detail):
            return copy.updateInvalidSignature(detail)
        case .network:
            return copy.updateNetworkFailure
        case .unexpected:
            return copy.updateUnexpectedFailure
        }
    }
}
