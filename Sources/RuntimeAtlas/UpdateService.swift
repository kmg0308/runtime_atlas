import Foundation
import RuntimeAtlasCore

enum UpdateServiceError: Error, Sendable {
    case invalidResponse
    case untrustedDownloadURL
    case noDownloadURL
    case noDownloadedFile
    case notAnAppBundle
    case invalidDownloadedArchive(String)
    case invalidDownloadedAppBundle(String)
    case invalidCodeSignature(String)
}

enum UpdateService {
    static let repository = GitHubRepository(owner: "kmg0308", name: "runtime_atlas")

    static func checkLatestRelease() async throws -> UpdateAvailability {
        let release = try await latestRelease(repository: repository)
        return UpdateAvailability(
            currentVersion: installedVersion(),
            installedBuildCommit: installedBuildCommit(),
            release: release
        )
    }

    static func downloadRelease(_ release: ReleaseInfo) async throws -> URL {
        guard isTrustedReleaseDownloadURL(release.zipURL, repository: repository) else {
            throw UpdateServiceError.untrustedDownloadURL
        }
        return try await download(
            url: release.zipURL,
            suggestedName: UpdateReleasePolicy.runtimeAtlasZipDownloadName(version: release.version)
        )
    }

    static func installDownloadedAppArchive(_ zipURL: URL) throws {
        try validateDownloadedAppArchive(zipURL)
        let targetApp = installTargetAppURL()
        guard targetApp.pathExtension == "app" else {
            throw UpdateServiceError.notAnAppBundle
        }

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runtime-atlas-update-\(UUID().uuidString).zsh")
        let currentPID = ProcessInfo.processInfo.processIdentifier

        let script = """
        #!/bin/zsh
        set -euo pipefail

        APP_PID=\(currentPID)
        ZIP=\(shellQuote(zipURL.path))
        TARGET=\(shellQuote(targetApp.path))
        SCRIPT=\(shellQuote(scriptURL.path))
        SYSTEM_CLI="/usr/local/bin/\(UpdateReleasePolicy.runtimeAtlasCLIHelperName)"
        LOG_DIR="$HOME/Library/Logs/RuntimeAtlas"
        LOG="$LOG_DIR/update.log"
        WORK="$(/usr/bin/mktemp -d)"
        HELPER="$WORK/install-root.zsh"
        TARGET_PARENT="$(/usr/bin/dirname "$TARGET")"
        TARGET_NAME="$(/usr/bin/basename "$TARGET")"
        TMP_TARGET="$TARGET.new.$$"
        OLD_TARGET="$TARGET.old.$$"

        /bin/mkdir -p "$LOG_DIR"
        exec >> "$LOG" 2>&1
        /bin/echo "[$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')] Starting update for $TARGET from $ZIP"

        plist_flag_enabled() {
            local value="${1:l}"
            [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
        }

        cleanup() {
            /bin/rm -rf "$WORK" "$TMP_TARGET"
            /bin/rm -f "$SCRIPT"
        }
        trap cleanup EXIT

        /usr/bin/find "$TARGET_PARENT" -maxdepth 1 \\( -name "$TARGET_NAME.new.*" -o -name "$TARGET_NAME.old.*" -o -name ".$TARGET_NAME.old.*" \\) -exec /bin/rm -rf {} + 2>/dev/null || true

        /usr/bin/ditto -x -k "$ZIP" "$WORK"
        NEW_APP="$WORK/\(UpdateReleasePolicy.runtimeAtlasArchiveName)"
        if [[ ! -d "$NEW_APP" ]]; then
            /bin/echo "\(UpdateReleasePolicy.runtimeAtlasArchiveName) was not found in archive." >&2
            exit 2
        fi

        /bin/rm -rf "$TMP_TARGET" "$OLD_TARGET"
        /usr/bin/ditto "$NEW_APP" "$TMP_TARGET"
        /usr/bin/xattr -cr "$TMP_TARGET" 2>/dev/null || true

        BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if [[ "$BUNDLE_ID" != "\(UpdateReleasePolicy.runtimeAtlasBundleIdentifier)" || "$EXECUTABLE" != "\(UpdateReleasePolicy.runtimeAtlasExecutableName)" ]]; then
            /bin/echo "Downloaded app bundle identity is invalid: $BUNDLE_ID / $EXECUTABLE" >&2
            exit 5
        fi
        BUNDLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if [[ "$BUNDLE_NAME" != "\(UpdateReleasePolicy.runtimeAtlasAppName)" ]]; then
            /bin/echo "Downloaded app bundle name is invalid: $BUNDLE_NAME" >&2
            exit 10
        fi
        PACKAGE_TYPE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if [[ "$PACKAGE_TYPE" != "APPL" ]]; then
            /bin/echo "Downloaded app package type is invalid: $PACKAGE_TYPE" >&2
            exit 11
        fi
        SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if [[ -z "${SHORT_VERSION//[[:space:]]/}" ]]; then
            /bin/echo "Downloaded app version is missing." >&2
            exit 12
        fi
        BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if [[ -z "${BUILD_VERSION//[[:space:]]/}" ]]; then
            /bin/echo "Downloaded app build number is missing." >&2
            exit 13
        fi
        LSUI_ELEMENT="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if plist_flag_enabled "$LSUI_ELEMENT"; then
            /bin/echo "Downloaded app must be a normal windowed app." >&2
            exit 8
        fi
        LS_BACKGROUND_ONLY="$(/usr/libexec/PlistBuddy -c 'Print :LSBackgroundOnly' "$TMP_TARGET/Contents/Info.plist" 2>/dev/null || true)"
        if plist_flag_enabled "$LS_BACKGROUND_ONLY"; then
            /bin/echo "Downloaded app must not be background-only." >&2
            exit 9
        fi
        if [[ ! -x "$TMP_TARGET/Contents/MacOS/\(UpdateReleasePolicy.runtimeAtlasExecutableName)" ]]; then
            /bin/echo "Downloaded app executable is missing." >&2
            exit 6
        fi
        if [[ ! -x "$TMP_TARGET/Contents/Helpers/\(UpdateReleasePolicy.runtimeAtlasCLIHelperName)" ]]; then
            /bin/echo "Downloaded app CLI helper is missing." >&2
            exit 14
        fi
        if ! /usr/bin/codesign --verify --deep --strict "$TMP_TARGET" >/dev/null 2>&1; then
            /bin/echo "Downloaded app code signature is invalid." >&2
            exit 7
        fi
        if ! /usr/bin/codesign --verify --strict "$TMP_TARGET/Contents/Helpers/\(UpdateReleasePolicy.runtimeAtlasCLIHelperName)" >/dev/null 2>&1; then
            /bin/echo "Downloaded CLI helper code signature is invalid." >&2
            exit 15
        fi

        /bin/cat > "$HELPER" <<'ROOTINSTALL'
        #!/bin/zsh
        set -euo pipefail
        APP_PID="$1"
        TARGET="$2"
        TMP_TARGET="$3"
        OLD_TARGET="$4"
        SYSTEM_CLI="$5"
        TARGET_PARENT="$(/usr/bin/dirname "$TARGET")"
        TARGET_NAME="$(/usr/bin/basename "$TARGET")"
        CLI_BACKUP="$SYSTEM_CLI.old.$$"
        CLI_STAGED="$SYSTEM_CLI.new.$$"

        rollback() {
            /bin/rm -rf "$TARGET"
            if [[ -e "$OLD_TARGET" ]]; then
                /bin/mv "$OLD_TARGET" "$TARGET"
            fi
            if [[ -e "$CLI_BACKUP" ]]; then
                /bin/rm -f "$SYSTEM_CLI"
                /bin/mv "$CLI_BACKUP" "$SYSTEM_CLI"
            fi
            /bin/rm -f "$CLI_STAGED"
        }

        if /bin/kill -0 "$APP_PID" 2>/dev/null; then
            /bin/kill -TERM "$APP_PID" 2>/dev/null || true
        fi

        for _ in {1..50}; do
            if ! /bin/kill -0 "$APP_PID" 2>/dev/null; then
                break
            fi
            /bin/sleep 0.2
        done

        if /bin/kill -0 "$APP_PID" 2>/dev/null; then
            /bin/echo "App did not terminate after TERM; sending KILL to $APP_PID."
            /bin/kill -KILL "$APP_PID" 2>/dev/null || true
            for _ in {1..20}; do
                if ! /bin/kill -0 "$APP_PID" 2>/dev/null; then
                    break
                fi
                /bin/sleep 0.2
            done
        fi

        if /bin/kill -0 "$APP_PID" 2>/dev/null; then
            /bin/echo "App process $APP_PID is still running; aborting install." >&2
            exit 4
        fi

        if [[ -e "$TARGET" ]]; then
            /bin/mv "$TARGET" "$OLD_TARGET"
        fi

        if ! /bin/mv "$TMP_TARGET" "$TARGET"; then
            if [[ -e "$OLD_TARGET" ]]; then
                /bin/mv "$OLD_TARGET" "$TARGET"
            fi
            exit 3
        fi

        if [[ -e "$SYSTEM_CLI" ]]; then
            if ! /usr/bin/ditto "$SYSTEM_CLI" "$CLI_BACKUP"; then
                rollback
                exit 16
            fi
            if ! /usr/bin/install -m 0755 "$TARGET/Contents/Helpers/runtime-atlas" "$CLI_STAGED"; then
                rollback
                exit 17
            fi
            if ! /usr/bin/codesign --verify --strict "$CLI_STAGED" >/dev/null 2>&1; then
                rollback
                exit 18
            fi
            if ! /bin/mv -f "$CLI_STAGED" "$SYSTEM_CLI"; then
                rollback
                exit 19
            fi
        fi

        if ! /bin/rm -rf "$OLD_TARGET" 2>/dev/null; then
            HIDDEN_OLD="$TARGET_PARENT/.$TARGET_NAME.old.$$"
            /bin/mv "$OLD_TARGET" "$HIDDEN_OLD" 2>/dev/null || true
        fi
        /bin/rm -f "$CLI_BACKUP" "$CLI_STAGED"
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET" 2>/dev/null || true
        /usr/bin/open -n "$TARGET"
        ROOTINSTALL
        /bin/chmod 755 "$HELPER"

        NEEDS_ADMIN=0
        if [[ ! -w "$TARGET_PARENT" || ( -e "$TARGET" && ! -w "$TARGET" ) ]]; then
            NEEDS_ADMIN=1
        fi
        if [[ -e "$SYSTEM_CLI" && ( ! -w "$SYSTEM_CLI" || ! -w "$(/usr/bin/dirname "$SYSTEM_CLI")" ) ]]; then
            NEEDS_ADMIN=1
        fi

        if [[ "$NEEDS_ADMIN" == "0" ]]; then
            /bin/zsh "$HELPER" "$APP_PID" "$TARGET" "$TMP_TARGET" "$OLD_TARGET" "$SYSTEM_CLI"
        else
            /usr/bin/osascript - "$HELPER" "$APP_PID" "$TARGET" "$TMP_TARGET" "$OLD_TARGET" "$SYSTEM_CLI" <<'OSA'
        on run argv
            set helperPath to item 1 of argv
            set appPID to item 2 of argv
            set targetPath to item 3 of argv
            set tmpTargetPath to item 4 of argv
            set oldTargetPath to item 5 of argv
            set systemCLIPath to item 6 of argv
            set commandText to "/bin/zsh " & quoted form of helperPath & " " & quoted form of appPID & " " & quoted form of targetPath & " " & quoted form of tmpTargetPath & " " & quoted form of oldTargetPath & " " & quoted form of systemCLIPath
            do shell script commandText with administrator privileges
        end run
        OSA
        fi

        /bin/echo "[$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')] Update installed and relaunched."
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "/usr/bin/nohup /bin/zsh \(shellQuote(scriptURL.path)) >/dev/null 2>&1 &"]
        try process.run()
        process.waitUntilExit()
    }

    static func installedBuildCommit() -> String {
        Bundle.main.object(forInfoDictionaryKey: "RuntimeAtlasBuildCommit") as? String ?? "dev"
    }

    static func installedVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private static func installTargetAppURL() -> URL {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.path.contains("/AppTranslocation/") {
            return URL(fileURLWithPath: "/Applications/RuntimeAtlas.app")
        }
        return bundleURL
    }

    private static func validateDownloadedAppArchive(_ zipURL: URL) throws {
        do {
            try UpdateArchiveValidator.validate(zipURL)
        } catch UpdateArchiveValidationError.missingArchive {
            throw UpdateServiceError.noDownloadedFile
        } catch UpdateArchiveValidationError.invalidArchive(let detail) {
            throw UpdateServiceError.invalidDownloadedArchive(detail)
        } catch UpdateArchiveValidationError.invalidAppBundle(let detail) {
            throw UpdateServiceError.invalidDownloadedAppBundle(detail)
        } catch UpdateArchiveValidationError.invalidCodeSignature(let detail) {
            throw UpdateServiceError.invalidCodeSignature(detail)
        }
    }

    private static func latestRelease(repository: GitHubRepository) async throws -> ReleaseInfo {
        let url = repository.apiBase.appendingPathComponent("releases/latest")
        let object = try await jsonObject(from: url)
        guard let dictionary = object as? [String: Any],
              let assets = dictionary["assets"] as? [[String: Any]] else {
            throw UpdateServiceError.invalidResponse
        }

        guard let selected = releaseZipAsset(from: assets),
              let urlString = selected["browser_download_url"] as? String,
              let downloadURL = URL(string: urlString) else {
            throw UpdateServiceError.noDownloadURL
        }
        guard isTrustedReleaseDownloadURL(downloadURL, repository: repository) else {
            throw UpdateServiceError.untrustedDownloadURL
        }

        let tag = (dictionary["tag_name"] as? String)
            ?? (dictionary["name"] as? String)
            ?? "0.0.0"
        let displayName = (dictionary["name"] as? String) ?? tag
        let htmlURL = (dictionary["html_url"] as? String).flatMap(URL.init(string:))
        let targetCommitish = (dictionary["target_commitish"] as? String) ?? ""
        return ReleaseInfo(
            version: UpdateReleasePolicy.normalizedVersion(tag),
            displayName: displayName,
            zipURL: downloadURL,
            htmlURL: htmlURL,
            targetCommitish: targetCommitish
        )
    }

    private static func jsonObject(from url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.setValue("RuntimeAtlas", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw UpdateServiceError.invalidResponse
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func releaseZipAsset(from assets: [[String: Any]]) -> [String: Any]? {
        assets.first { asset in
            assetName(asset) == "runtimeatlas.zip"
        } ?? assets.first { asset in
            UpdateReleasePolicy.isInstallableRuntimeAtlasZipAssetName(assetName(asset))
        }
    }

    private static func assetName(_ asset: [String: Any]) -> String {
        (asset["name"] as? String ?? "").lowercased()
    }

    private static func isTrustedReleaseDownloadURL(
        _ url: URL,
        repository: GitHubRepository
    ) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com" else {
            return false
        }
        let prefix = "/\(repository.owner)/\(repository.name)/releases/download/"
        return url.path.lowercased().hasPrefix(prefix.lowercased())
    }

    private static func download(url: URL, suggestedName: String) async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("RuntimeAtlas", forHTTPHeaderField: "User-Agent")
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw UpdateServiceError.invalidResponse
        }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let destination = availableDownloadURL(in: downloads, suggestedName: suggestedName)
        try FileManager.default.copyItem(at: tempURL, to: destination)
        return destination
    }

    private static func availableDownloadURL(in directory: URL, suggestedName: String) -> URL {
        let fileName = URL(fileURLWithPath: suggestedName).lastPathComponent
        let safeName = fileName.isEmpty ? "RuntimeAtlas.zip" : fileName
        let base = URL(fileURLWithPath: safeName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: safeName).pathExtension
        var candidate = directory.appendingPathComponent(safeName)
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
            candidate = directory.appendingPathComponent(name)
            suffix += 1
        }
        return candidate
    }

    private static func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
