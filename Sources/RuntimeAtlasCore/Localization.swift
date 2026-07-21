import Foundation

public struct AtlasCopy: Sendable {
    public let language: AppLanguage

    public init(language: AppLanguage) {
        self.language = language
    }

    private func value(english: String, korean: String) -> String {
        language == .korean ? korean : english
    }

    public var appName: String { "Runtime Atlas" }
    public var atlasMenu: String { language == .korean ? "Atlas" : "Atlas" }
    public var addRepository: String { value(english: "Add Repository", korean: "저장소 추가") }
    public var addRepositoryEllipsis: String { value(english: "Add Repository…", korean: "저장소 추가…") }
    public var refreshing: String { value(english: "Refreshing", korean: "새로고침 중") }
    public var refresh: String { value(english: "Refresh", korean: "새로고침") }
    public var refreshingAccessibility: String {
        value(english: "Refreshing Runtime Atlas", korean: "Runtime Atlas 새로고침 중")
    }
    public var refreshAccessibility: String {
        value(english: "Refresh Runtime Atlas", korean: "Runtime Atlas 새로고침")
    }
    public var removeRepositoryQuestion: String {
        value(english: "Remove Repository?", korean: "저장소를 제거할까요?")
    }
    public var remove: String { value(english: "Remove", korean: "제거") }
    public var cancel: String { value(english: "Cancel", korean: "취소") }
    public func stopTracking(_ name: String) -> String {
        value(
            english: "Stop tracking \(name). Runtime Atlas does not delete the repository or its worktrees.",
            korean: "\(name) 추적을 중단합니다. Runtime Atlas는 저장소나 워크트리를 삭제하지 않습니다."
        )
    }
    public var repositories: String { value(english: "Repositories", korean: "저장소") }
    public func registeredRepositories(_ count: Int) -> String {
        value(english: "\(count) registered repositories", korean: "등록된 저장소 \(count)개")
    }
    public var readingLocalState: String {
        value(english: "Reading local state…", korean: "로컬 상태를 읽는 중…")
    }
    public var noRepositories: String { value(english: "No repositories", korean: "등록된 저장소 없음") }
    public var addRepositoryToDiscover: String {
        value(
            english: "Add a Git repository to discover its worktrees.",
            korean: "Git 저장소를 추가해 워크트리를 확인하세요."
        )
    }
    public func removeNamedRepository(_ name: String) -> String {
        value(english: "Remove \(name)", korean: "\(name) 제거")
    }
    public var removeRepositoryHelp: String { value(english: "Remove Repository", korean: "저장소 제거") }
    public var repositoryUnavailable: String {
        value(english: "Repository is unavailable.", korean: "저장소를 사용할 수 없습니다.")
    }
    public var noWorktreesFound: String {
        value(english: "No worktrees found", korean: "워크트리를 찾지 못함")
    }
    public func unavailable(_ reason: String) -> String {
        value(english: "Unavailable — \(localizedCoreMessage(reason))", korean: "사용 불가 — \(localizedCoreMessage(reason))")
    }
    public var dirtyWorktree: String { value(english: "Dirty worktree", korean: "변경 사항이 있는 워크트리") }
    public var detachedHead: String { value(english: "Detached HEAD", korean: "분리된 HEAD") }
    public var unknownBranch: String { value(english: "Unknown branch", korean: "알 수 없는 브랜치") }
    public var dirty: String { value(english: "dirty", korean: "변경 있음") }
    public var clean: String { value(english: "clean", korean: "깨끗함") }
    public var noAvailableWorktree: String {
        value(english: "No available worktree", korean: "사용 가능한 워크트리 없음")
    }
    public var buildRuntimeMap: String {
        value(english: "Build your runtime map", korean: "런타임 지도를 시작하세요")
    }
    public var reviewUnavailableMessage: String {
        value(
            english: "Review the unavailable repository message in the sidebar.",
            korean: "사이드바에서 저장소를 사용할 수 없는 이유를 확인하세요."
        )
    }
    public var addRepositoryEmptyDescription: String {
        value(
            english: "Add a Git repository to connect code, local runtimes, logical DB labels, and SHA-bound evidence.",
            korean: "Git 저장소를 추가해 코드, 로컬 런타임, 논리 DB 라벨과 SHA 기반 검증 증거를 연결하세요."
        )
    }

    public var localDataIssue: String { value(english: "Local data issue", korean: "로컬 데이터 문제") }
    public var notice: String { value(english: "Notice", korean: "알림") }
    public var code: String { value(english: "Code", korean: "코드") }
    public var codeSubtitle: String {
        value(
            english: "The checked-out code identity and local-only DB label.",
            korean: "체크아웃된 코드 식별 정보와 로컬 전용 DB 라벨입니다."
        )
    }
    public var runtimeMap: String { value(english: "Runtime Map", korean: "런타임 지도") }
    public var runtimeMapSubtitle: String {
        value(
            english: "Only listeners and containers whose cwd or mount falls inside this worktree.",
            korean: "cwd 또는 mount가 이 워크트리 안에 있는 리스너와 컨테이너만 표시합니다."
        )
    }
    public var evidence: String { value(english: "Evidence", korean: "검증 증거") }
    public var evidenceSubtitle: String {
        value(
            english: "Recorded results stay immutable; a different current SHA is shown as STALE.",
            korean: "기록은 변경하지 않으며 현재 SHA가 다르면 STALE로 표시합니다."
        )
    }
    public var detachedBadge: String { value(english: "DETACHED", korean: "분리됨") }
    public var noBranchBadge: String { value(english: "NO BRANCH", korean: "브랜치 없음") }
    public var dirtyBadge: String { value(english: "DIRTY", korean: "변경 있음") }
    public var cleanBadge: String { value(english: "CLEAN", korean: "깨끗함") }
    public var worktreeUnavailable: String {
        value(english: "Worktree unavailable", korean: "워크트리 사용 불가")
    }
    public var gitCouldNotInspectWorktree: String {
        value(english: "Git could not inspect this worktree.", korean: "Git이 이 워크트리를 검사하지 못했습니다.")
    }
    public var branch: String { value(english: "Branch", korean: "브랜치") }
    public var fullSHA: String { value(english: "Full SHA", korean: "전체 SHA") }
    public var workingTree: String { value(english: "Working tree", korean: "작업 트리") }
    public var unknown: String { value(english: "Unknown", korean: "알 수 없음") }
    public var dirtyWorkingTree: String {
        value(english: "Dirty — uncommitted changes present", korean: "변경 있음 — 커밋하지 않은 변경 사항 존재")
    }
    public var cleanWorkingTree: String { value(english: "Clean", korean: "깨끗함") }
    public var logicalDBLabel: String {
        value(english: "Logical DB profile label", korean: "논리 DB 프로필 라벨")
    }
    public var logicalDBDescription: String {
        value(
            english: "A name only. Runtime Atlas never reads or stores a DB URL or credential.",
            korean: "이름만 저장합니다. Runtime Atlas는 DB URL이나 인증 정보를 읽거나 저장하지 않습니다."
        )
    }
    public var logicalDBPlaceholder: String { value(english: "e.g. refactoring_test", korean: "예: refactoring_test") }
    public var save: String { value(english: "Save", korean: "저장") }
    public var saveLogicalDBLabel: String {
        value(english: "Save logical DB profile label", korean: "논리 DB 프로필 라벨 저장")
    }
    public var unavailableValue: String { value(english: "Unavailable", korean: "사용 불가") }
    public func detachedAt(_ sha: String) -> String {
        value(english: "Detached at \(sha)", korean: "\(sha)에서 분리됨")
    }
    public var processesUnavailable: String {
        value(english: "Processes unavailable", korean: "프로세스 사용 불가")
    }
    public var listeningPortsUnreadable: String {
        value(english: "Listening ports could not be read.", korean: "LISTEN 포트를 읽지 못했습니다.")
    }
    public var noMappedListeningProcess: String {
        value(english: "No mapped listening process", korean: "연결된 LISTEN 프로세스 없음")
    }
    public var noListenProcessInWorktree: String {
        value(
            english: "No LISTEN process cwd falls inside this worktree.",
            korean: "cwd가 이 워크트리 안에 있는 LISTEN 프로세스가 없습니다."
        )
    }
    public var cwdUnavailable: String { value(english: "cwd unavailable", korean: "cwd 사용 불가") }
    public var dockerUnavailable: String { value(english: "Docker unavailable", korean: "Docker 사용 불가") }
    public var dockerCouldNotBeRead: String {
        value(english: "Docker could not be read.", korean: "Docker 정보를 읽지 못했습니다.")
    }
    public var unavailableBadge: String { value(english: "UNAVAILABLE", korean: "사용 불가") }
    public var noMappedRunningContainer: String {
        value(english: "No mapped running container", korean: "연결된 실행 컨테이너 없음")
    }
    public var dockerAvailableNoMount: String {
        value(
            english: "Docker is available; no running container mounts this worktree.",
            korean: "Docker는 사용 가능하지만 이 워크트리를 mount한 실행 컨테이너가 없습니다."
        )
    }
    public var dockerAvailableBadge: String { value(english: "DOCKER AVAILABLE", korean: "DOCKER 사용 가능") }
    public func runtimeMapAccessibility(_ name: String) -> String {
        value(english: "Runtime map for \(name)", korean: "\(name)의 런타임 지도")
    }

    public var currentSHA: String { value(english: "CURRENT SHA", korean: "현재 SHA") }
    public var latestCurrentEvidence: String {
        value(english: "Latest current-SHA evidence", korean: "최신 현재-SHA 증거")
    }
    public var noCurrentEvidence: String {
        value(english: "No current-SHA evidence", korean: "현재-SHA 증거 없음")
    }
    public var runEvidenceCommand: String {
        value(
            english: "Run runtime-atlas verify or record a browser/manual result from this worktree.",
            korean: "이 워크트리에서 runtime-atlas verify를 실행하거나 브라우저/수동 결과를 기록하세요."
        )
    }
    public var history: String { value(english: "History", korean: "기록") }
    public var noEvidenceHistory: String {
        value(english: "No evidence has been recorded for this worktree.", korean: "이 워크트리에 기록된 증거가 없습니다.")
    }
    public func currentSHARecordCount(status: EvidenceDisplayStatus, count: Int) -> String {
        value(
            english: "\(status.rawValue), \(count) current SHA records",
            korean: "\(status.rawValue), 현재 SHA 기록 \(count)개"
        )
    }
    public func evidenceKind(_ kind: EvidenceKind) -> String {
        switch (language, kind) {
        case (.korean, .command): "명령"
        case (.korean, .browser): "브라우저"
        case (.korean, .manual): "수동"
        case (.english, _): kind.rawValue.uppercased()
        }
    }
    public func exitCode(_ code: Int32) -> String {
        value(english: "EXIT \(code)", korean: "종료 코드 \(code)")
    }
    public var dirtyAtRecordTime: String {
        value(english: "dirty at record time", korean: "기록 당시 변경 있음")
    }
    public var cleanAtRecordTime: String {
        value(english: "clean at record time", korean: "기록 당시 깨끗함")
    }
    public func viewport(_ viewport: String) -> String {
        value(english: "viewport \(viewport)", korean: "화면 크기 \(viewport)")
    }
    public func wasStatus(_ status: EvidenceStatus) -> String {
        value(english: "was \(status.rawValue)", korean: "기록 상태 \(status.rawValue)")
    }
    public func evidenceAccessibility(_ evidence: EvidencePresentation) -> String {
        let stale = evidence.displayStatus == .stale
            ? value(
                english: ", recorded status \(evidence.record.status.rawValue)",
                korean: ", 기록 상태 \(evidence.record.status.rawValue)"
            )
            : ""
        return value(
            english: "\(evidence.displayStatus.rawValue) \(evidence.record.kind.rawValue) evidence\(stale), SHA \(evidence.record.sha.prefix(7))",
            korean: "\(evidence.displayStatus.rawValue) \(evidenceKind(evidence.record.kind)) 증거\(stale), SHA \(evidence.record.sha.prefix(7))"
        )
    }
    public func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var settingsTitle: String { value(english: "Language", korean: "언어") }
    public var settingsDescription: String {
        value(
            english: "Choose the language used throughout Runtime Atlas.",
            korean: "Runtime Atlas 전체에서 사용할 언어를 선택하세요."
        )
    }
    public var languageChoice: String { value(english: "App language", korean: "앱 언어") }
    public var settingsPersistence: String {
        value(
            english: "The choice is stored only in Runtime Atlas local settings.",
            korean: "선택한 언어는 Runtime Atlas 로컬 설정에만 저장됩니다."
        )
    }
    public var koreanName: String { "한국어" }
    public var englishName: String { "English" }
    public var languageSaveFailed: String {
        value(english: "The language setting could not be saved.", korean: "언어 설정을 저장하지 못했습니다.")
    }

    public var refreshFailed: String {
        value(english: "Runtime Atlas could not refresh local state.", korean: "Runtime Atlas가 로컬 상태를 새로고침하지 못했습니다.")
    }
    public var chooseRepositoryMessage: String {
        value(
            english: "Choose the Git repository you want Runtime Atlas to track.",
            korean: "Runtime Atlas에서 추적할 Git 저장소를 선택하세요."
        )
    }
    public var repositoryAddFailed: String {
        value(english: "Repository could not be added.", korean: "저장소를 추가하지 못했습니다.")
    }
    public var repositoryRemoveFailed: String {
        value(english: "Repository could not be removed.", korean: "저장소를 제거하지 못했습니다.")
    }
    public var logicalDBSaved: String {
        value(english: "Logical DB label saved.", korean: "논리 DB 라벨을 저장했습니다.")
    }
    public var logicalDBSaveFailed: String {
        value(english: "Logical DB label could not be saved.", korean: "논리 DB 라벨을 저장하지 못했습니다.")
    }
    public var logicalDBValidation: String {
        value(
            english: "Use 1-80 letters, numbers, periods, underscores, or hyphens.",
            korean: "영문자, 숫자, 마침표, 밑줄 또는 하이픈을 1~80자로 입력하세요."
        )
    }

    public var updates: String { value(english: "Updates", korean: "업데이트") }
    public var checkForUpdates: String {
        value(english: "Check for Updates", korean: "업데이트 확인")
    }
    public var checkForUpdatesEllipsis: String {
        value(english: "Check for Updates…", korean: "업데이트 확인…")
    }
    public func updateVersionLabel(_ version: String) -> String {
        value(english: "Update \(version)", korean: "\(version) 업데이트")
    }
    public var updateReady: String {
        value(english: "Ready to check for updates.", korean: "업데이트를 확인할 수 있습니다.")
    }
    public var checkingLatestRelease: String {
        value(english: "Checking the latest release…", korean: "최신 릴리스를 확인하는 중…")
    }
    public func updateAvailable(_ version: String) -> String {
        value(english: "Version \(version) is available.", korean: "버전 \(version)을 사용할 수 있습니다.")
    }
    public func upToDateChecked(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeStyle = .medium
        return value(
            english: "Runtime Atlas is up to date. Checked at \(formatter.string(from: date)).",
            korean: "Runtime Atlas가 최신 버전입니다. \(formatter.string(from: date))에 확인했습니다."
        )
    }
    public func downloadingVersion(_ version: String) -> String {
        value(english: "Downloading version \(version)…", korean: "버전 \(version)을 다운로드하는 중…")
    }
    public func installingVersion(_ version: String) -> String {
        value(english: "Installing version \(version)…", korean: "버전 \(version)을 설치하는 중…")
    }
    public var installingAndRelaunching: String {
        value(english: "Installing and relaunching…", korean: "설치 후 다시 실행하는 중…")
    }
    public var updateInProgress: String {
        value(english: "Update in progress", korean: "업데이트 진행 중")
    }
    public var updateInstallHint: String {
        value(
            english: "Downloads the verified RuntimeAtlas.zip release, replaces this app, and relaunches it.",
            korean: "검증된 RuntimeAtlas.zip 릴리스를 내려받아 현재 앱을 교체하고 다시 실행합니다."
        )
    }
    public var updateDetails: String { value(english: "Details", korean: "자세히") }
    public var installingEllipsis: String { value(english: "Installing…", korean: "설치 중…") }
    public var updatingEllipsis: String { value(english: "Updating…", korean: "업데이트 중…") }
    public var updateNow: String { value(english: "Update Now", korean: "지금 업데이트") }
    public var close: String { value(english: "Close", korean: "닫기") }
    public var currentVersion: String { value(english: "Current", korean: "현재 버전") }
    public var availableVersion: String { value(english: "Available", korean: "사용 가능") }
    public var updateSigningNotice: String {
        value(
            english: "Updates come only from kmg0308/runtime_atlas GitHub Releases. Builds are ad-hoc signed and are not notarized.",
            korean: "업데이트는 kmg0308/runtime_atlas GitHub Release에서만 받습니다. 빌드는 ad-hoc 서명되며 공증되지 않았습니다."
        )
    }
    public var installAndRelaunch: String {
        value(english: "Install and Relaunch", korean: "설치 후 다시 실행")
    }
    public var installing: String { value(english: "Installing", korean: "설치 중") }
    public var readyToInstall: String { value(english: "Ready to install", korean: "설치 준비 완료") }
    public var updateAvailableTitle: String { value(english: "Update available", korean: "업데이트 사용 가능") }
    public var updateCheckFailed: String { value(english: "Update check failed", korean: "업데이트 확인 실패") }
    public var upToDate: String { value(english: "Up to date", korean: "최신 버전") }
    public var notChecked: String { value(english: "Not checked", korean: "확인하지 않음") }
    public var noUpdate: String { value(english: "No update", korean: "업데이트 없음") }

    public var updateInvalidResponse: String {
        value(english: "GitHub returned an invalid response.", korean: "GitHub가 올바르지 않은 응답을 반환했습니다.")
    }
    public var updateUntrustedDownloadURL: String {
        value(
            english: "The release download URL is not the trusted Runtime Atlas repository.",
            korean: "릴리스 다운로드 URL이 신뢰하는 Runtime Atlas 저장소 주소가 아닙니다."
        )
    }
    public var updateNoDownloadURL: String {
        value(english: "No installable RuntimeAtlas.zip was found.", korean: "설치 가능한 RuntimeAtlas.zip을 찾지 못했습니다.")
    }
    public var updateNoDownloadedFile: String {
        value(english: "Download a release ZIP first.", korean: "먼저 릴리스 ZIP을 다운로드하세요.")
    }
    public var updateNotPackagedApp: String {
        value(
            english: "Updates can only install into a packaged .app build.",
            korean: "패키징된 .app 빌드에서만 업데이트를 설치할 수 있습니다."
        )
    }
    public func updateInvalidArchive(_ detail: String) -> String {
        value(
            english: "Downloaded update archive is invalid: \(detail)",
            korean: "다운로드한 업데이트 압축 파일이 올바르지 않습니다: \(detail)"
        )
    }
    public func updateInvalidBundle(_ detail: String) -> String {
        value(
            english: "Downloaded app bundle is invalid: \(detail)",
            korean: "다운로드한 앱 번들이 올바르지 않습니다: \(detail)"
        )
    }
    public func updateInvalidSignature(_ detail: String) -> String {
        value(
            english: "Downloaded app code signature is invalid: \(detail)",
            korean: "다운로드한 앱 코드 서명이 올바르지 않습니다: \(detail)"
        )
    }
    public var updateNetworkFailure: String {
        value(english: "The update service could not reach GitHub.", korean: "업데이트 서비스가 GitHub에 연결하지 못했습니다.")
    }
    public var updateUnexpectedFailure: String {
        value(english: "The update could not be completed.", korean: "업데이트를 완료하지 못했습니다.")
    }

    public func localizedCoreMessage(_ message: String) -> String {
        guard language == .korean else { return message }
        return Self.koreanCoreMessages[message] ?? message
    }

    public static let localizedCoreMessageKeys: [String] = Array(koreanCoreMessages.keys).sorted()

    private static let koreanCoreMessages: [String: String] = [
        "Repository path is missing.": "저장소 경로가 존재하지 않습니다.",
        "Git could not inspect this repository.": "Git이 이 저장소를 검사하지 못했습니다.",
        "Path is not an available Git repository.": "이 경로는 사용 가능한 Git 저장소가 아닙니다.",
        "No Git worktrees were found.": "Git 워크트리를 찾지 못했습니다.",
        "Worktree path is missing.": "워크트리 경로가 존재하지 않습니다.",
        "Git could not inspect this worktree.": "Git이 이 워크트리를 검사하지 못했습니다.",
        "Listening TCP ports could not be read.": "LISTEN 중인 TCP 포트를 읽지 못했습니다.",
        "Docker CLI is not installed.": "Docker CLI가 설치되어 있지 않습니다.",
        "Docker CLI could not be launched.": "Docker CLI를 실행하지 못했습니다.",
        "Docker containers could not be read.": "Docker 컨테이너를 읽지 못했습니다.",
        "Docker container details could not be read.": "Docker 컨테이너 상세 정보를 읽지 못했습니다.",
        "Docker container details could not be parsed.": "Docker 컨테이너 상세 정보를 해석하지 못했습니다.",
        "Docker is unavailable: permission denied.": "Docker를 사용할 수 없습니다: 권한이 거부되었습니다.",
        "Docker daemon is not responding.": "Docker daemon이 응답하지 않습니다.",
        "Docker is unavailable.": "Docker를 사용할 수 없습니다.",
        "Unknown": "알 수 없음",
        "Unnamed": "이름 없음",
        "Unknown image": "알 수 없는 이미지",
        "Runtime Atlas could not create its local data directory.": "Runtime Atlas가 로컬 데이터 폴더를 만들지 못했습니다.",
        "Runtime Atlas local data is busy or cannot be locked.": "Runtime Atlas 로컬 데이터가 사용 중이거나 잠글 수 없습니다.",
        "Runtime Atlas could not save local data.": "Runtime Atlas가 로컬 데이터를 저장하지 못했습니다.",
        "The repository configuration file is damaged; an empty configuration is being used until the next save.": "저장소 설정 파일이 손상되어 다음 저장 전까지 빈 설정을 사용합니다.",
        "The evidence file is damaged; no history is shown until the next evidence record is saved.": "증거 파일이 손상되어 다음 증거를 저장할 때까지 기록을 표시하지 않습니다."
    ]
}
