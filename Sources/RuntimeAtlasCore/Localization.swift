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
    public var nextRecentWorktree: String {
        value(english: "Next Recently Viewed Worktree", korean: "다음 최근 본 워크트리")
    }
    public var previousRecentWorktree: String {
        value(english: "Previous Recently Viewed Worktree", korean: "이전 최근 본 워크트리")
    }
    public var recentlyViewedWorktrees: String {
        value(english: "Recently Viewed Worktrees", korean: "최근 본 워크트리")
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
            english: "Add a Git repository to see each working folder (Git worktree).",
            korean: "Git 저장소를 추가하면 각 작업 폴더(Git worktree)를 함께 보여줍니다."
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
        value(english: "No working folders (Git worktrees) found", korean: "작업 폴더(Git worktree)를 찾지 못함")
    }
    public func unavailable(_ reason: String) -> String {
        value(english: "Unavailable — \(localizedCoreMessage(reason))", korean: "사용 불가 — \(localizedCoreMessage(reason))")
    }
    public var dirtyWorktree: String { value(english: "Uncommitted changes", korean: "커밋하지 않은 변경 있음") }
    public var detachedHead: String { value(english: "Not on a branch (detached HEAD)", korean: "브랜치에 연결되지 않음(detached HEAD)") }
    public var unknownBranch: String { value(english: "Unknown branch", korean: "알 수 없는 브랜치") }
    public var dirty: String { value(english: "uncommitted changes", korean: "커밋하지 않은 변경 있음") }
    public var clean: String { value(english: "no uncommitted changes", korean: "커밋하지 않은 변경 없음") }
    public var noAvailableWorktree: String {
        value(english: "No available working folder (Git worktree)", korean: "사용 가능한 작업 폴더(Git worktree) 없음")
    }
    public var buildRuntimeMap: String {
        value(english: "See what is running", korean: "무엇이 실행 중인지 확인하세요")
    }
    public var reviewUnavailableMessage: String {
        value(
            english: "Review the unavailable repository message in the sidebar.",
            korean: "사이드바에서 저장소를 사용할 수 없는 이유를 확인하세요."
        )
    }
    public var addRepositoryEmptyDescription: String {
        value(
            english: "Add a Git repository to connect code versions with processes, ports, and containers.",
            korean: "Git 저장소를 추가해 코드 버전과 프로세스, 포트, 컨테이너를 연결하세요."
        )
    }

    public var localDataIssue: String { value(english: "Local data issue", korean: "로컬 데이터 문제") }
    public var notice: String { value(english: "Notice", korean: "알림") }
    public var runtimeMap: String { value(english: "Runtime Status", korean: "실행 상태") }
    public var runtimeMapSubtitle: String {
        value(
            english: "Processes, containers, and open ports linked to this working folder.",
            korean: "이 작업 폴더와 연결된 프로세스, 컨테이너와 열린 포트를 보여줍니다."
        )
    }
    public var actions: String { value(english: "Commands", korean: "명령어") }
    public var actionsSubtitle: String {
        value(
            english: "Configure the commands shared by every working folder in this repository.",
            korean: "이 저장소의 모든 작업 폴더가 함께 쓰는 명령어를 설정합니다."
        )
    }
    public var worktreeActionsSubtitle: String {
        value(
            english: "Run the repository's shared commands in this working folder.",
            korean: "저장소에 설정한 명령어를 이 작업 폴더에서 실행합니다."
        )
    }
    public var configureActions: String { value(english: "Configure Commands", korean: "명령어 설정") }
    public func repositoryActionsFor(_ name: String) -> String {
        value(english: "\(name) Commands", korean: "\(name) 명령어")
    }
    public var noActions: String { value(english: "No commands configured", korean: "설정한 명령어 없음") }
    public var noActionsHelp: String {
        value(
            english: "Add only commands that belong to this repository. Every working folder shares the same list.",
            korean: "이 저장소에서 공통으로 쓰는 명령어만 추가하세요. 모든 작업 폴더가 같은 목록을 공유합니다."
        )
    }
    public var addAction: String { value(english: "Add Command", korean: "명령어 추가") }
    public var editAction: String { value(english: "Edit Command", korean: "명령어 편집") }
    public var actionName: String { value(english: "Command name", korean: "명령어 이름") }
    public var commandTemplate: String { value(english: "Command", korean: "명령어") }
    public var actionKind: String { value(english: "How it runs", korean: "실행 방식") }
    public var oneTimeTask: String { value(english: "Run once", korean: "한 번 실행") }
    public var runningSession: String { value(english: "Keep running", korean: "계속 실행") }
    public var runFrom: String { value(english: "Run from", korean: "실행 위치") }
    public var commandRunLocation: String { value(english: "Working folder to run in", korean: "실행할 작업 폴더") }
    public var selectedWorktreeLocation: String { value(english: "Selected working folder", korean: "선택한 작업 폴더") }
    public var repositoryRootLocation: String { value(english: "Main repository folder", korean: "기준 저장소 폴더") }
    public var destructiveAction: String { value(english: "Can delete or overwrite data", korean: "데이터를 삭제하거나 덮어쓸 수 있음") }
    public var effects: String { value(english: "What this command changes (one per line)", korean: "이 명령어가 바꾸는 것 (한 줄에 하나)") }
    public var inputs: String { value(english: "Inputs", korean: "실행 전 입력") }
    public var addInput: String { value(english: "Add Input", korean: "입력 추가") }
    public var inputKey: String { value(english: "Placeholder key", korean: "치환 이름") }
    public var inputLabel: String { value(english: "Shown label", korean: "표시 이름") }
    public var textInput: String { value(english: "Text", korean: "텍스트") }
    public var worktreeInput: String { value(english: "Working folder", korean: "작업 폴더 선택") }
    public var checkboxInput: String { value(english: "Checkbox flag", korean: "체크박스 옵션") }
    public var flagArgument: String { value(english: "Argument when checked", korean: "체크 시 붙일 인수") }
    public var commandPlaceholderHelp: String {
        value(english: "Use a whole argument such as {{target}}. Pipes, redirects, &&, and shell expansion are not supported.", korean: "{{target}}처럼 인수 전체를 치환할 수 있습니다. 파이프, 리다이렉트, &&, 셸 확장은 지원하지 않습니다.")
    }
    public var start: String { value(english: "Start", korean: "시작") }
    public var run: String { value(english: "Run", korean: "실행") }
    public var stop: String { value(english: "Stop", korean: "중지") }
    public var stopping: String { value(english: "Stopping", korean: "중지 중") }
    public var running: String { value(english: "Running", korean: "실행 중") }
    public var runningOutsideApp: String { value(english: "External · Running", korean: "외부 실행 중") }
    public var externalRunningHelp: String {
        value(
            english: "A listener is already running from this working folder. Close it in Runtime Status before starting another one.",
            korean: "이 작업 폴더에서 이미 포트를 연 프로세스가 있습니다. 새로 실행하려면 실행 상태에서 해당 포트를 먼저 닫으세요."
        )
    }
    public var detectExternalListener: String {
        value(english: "Detect a listener already running in the working folder", korean: "작업 폴더에서 이미 실행 중인 서버 감지")
    }
    public var detectExternalListenerHelp: String {
        value(
            english: "Use this for server commands. Any process with an open TCP port and this working folder as its cwd is shown as running outside the app.",
            korean: "서버 명령어에 사용합니다. 이 작업 폴더를 실행 위치(cwd)로 사용하며 TCP 포트를 연 프로세스가 있으면 외부 실행으로 표시합니다."
        )
    }
    public var succeeded: String { value(english: "Finished", korean: "완료") }
    public var stopped: String { value(english: "Stopped", korean: "중지됨") }
    public func failedExit(_ code: Int32) -> String { value(english: "Failed (exit \(code))", korean: "실패 (종료 \(code))") }
    public var output: String { value(english: "Output", korean: "실행 내용") }
    public var confirmAction: String { value(english: "Review and Run", korean: "확인 후 실행") }
    public var destructiveWarning: String {
        value(english: "Review the exact command and effects. This confirmation is required every time.", korean: "실제 명령과 영향을 확인하세요. 이 확인은 실행할 때마다 필요합니다.")
    }
    public var exactCommand: String { value(english: "Exact command", korean: "실제 실행 명령") }
    public var actionSaved: String { value(english: "Command saved.", korean: "명령어를 저장했습니다.") }
    public var actionSaveFailed: String { value(english: "Command could not be saved.", korean: "명령어를 저장하지 못했습니다.") }
    public var worktreeOrderSaveFailed: String {
        value(english: "Working folder order could not be saved.", korean: "작업 폴더 순서를 저장하지 못했습니다.")
    }
    public var actionRemoveFailed: String { value(english: "Command could not be removed.", korean: "명령어를 제거하지 못했습니다.") }
    public var actionLaunchFailed: String { value(english: "Command could not be started.", korean: "명령어를 시작하지 못했습니다.") }
    public var deleteAction: String { value(english: "Delete Command", korean: "명령어 삭제") }
    public var sessionCloseNotice: String {
        value(english: "Runtime Atlas stops commands it kept running when the app quits.", korean: "Runtime Atlas가 계속 실행한 명령어는 앱을 종료하면 함께 중지됩니다.")
    }
    public func customActionError(_ error: CustomActionError) -> String {
        guard language == .korean else { return error.localizedDescription }
        return switch error {
        case .invalidName: "명령어 이름은 1~60자로 입력하세요."
        case .invalidTemplate(let reason): "명령어가 올바르지 않습니다: \(reason)"
        case .invalidInput(let reason): "입력 설정이 올바르지 않습니다: \(reason)"
        case .missingValue(let key): "{{\(key)}} 값을 입력하세요."
        case .invalidWorktree(let path): "등록된 작업 폴더가 아닙니다: \(path)"
        }
    }
    public var detachedBadge: String { value(english: "NOT ON BRANCH · DETACHED", korean: "브랜치 없음 · DETACHED") }
    public var noBranchBadge: String { value(english: "NO BRANCH", korean: "브랜치 없음") }
    public var dirtyBadge: String { value(english: "UNCOMMITTED CHANGES", korean: "변경 있음") }
    public var cleanBadge: String { value(english: "NO CHANGES", korean: "변경 없음") }
    public var worktreeUnavailable: String {
        value(english: "Worktree unavailable", korean: "워크트리 사용 불가")
    }
    public var gitCouldNotInspectWorktree: String {
        value(english: "Git could not inspect this worktree.", korean: "Git이 이 워크트리를 검사하지 못했습니다.")
    }
    public var branch: String { value(english: "Branch", korean: "브랜치") }
    public var fullSHA: String { value(english: "Code version (full SHA)", korean: "코드 버전 (전체 SHA)") }
    public var workingTree: String { value(english: "Uncommitted changes", korean: "커밋하지 않은 변경") }
    public var unknown: String { value(english: "Unknown", korean: "알 수 없음") }
    public var dirtyWorkingTree: String {
        value(english: "Present (Git dirty)", korean: "있음(Git dirty)")
    }
    public var cleanWorkingTree: String { value(english: "None (Git clean)", korean: "없음(Git clean)") }
    public var save: String { value(english: "Save", korean: "저장") }
    public var unavailableValue: String { value(english: "Unavailable", korean: "사용 불가") }
    public func detachedAt(_ sha: String) -> String {
        value(english: "Detached at \(sha)", korean: "\(sha)에서 분리됨")
    }
    public var processesUnavailable: String {
        value(english: "Processes unavailable", korean: "프로세스 사용 불가")
    }
    public var listeningPortsUnreadable: String {
        value(english: "Open ports could not be read (LISTEN).", korean: "열린 포트(LISTEN)를 읽지 못했습니다.")
    }
    public var noMappedListeningProcess: String {
        value(english: "No process opening a port", korean: "포트를 열고 기다리는 프로세스 없음")
    }
    public var noListenProcessInWorktree: String {
        value(
            english: "No process with an open LISTEN port is running from this working folder (cwd).",
            korean: "이 작업 폴더에서 실행되고(cwd) 포트를 열어 둔(LISTEN) 프로세스가 없습니다."
        )
    }
    public var closePorts: String { value(english: "Close ports", korean: "포트 닫기") }
    public var closePortsQuestion: String { value(english: "Close these ports?", korean: "이 포트를 닫을까요?") }
    public var stopProcess: String { value(english: "Stop process", korean: "프로세스 종료") }
    public func processStopWarning(name: String, pid: Int32, ports: String) -> String {
        value(
            english: "This sends a normal termination request to \(name) (PID \(pid)) to close \(ports). Other work performed by this process also stops.",
            korean: "\(name)(PID \(pid))에 정상 종료를 요청해 \(ports) 포트를 닫습니다. 이 프로세스가 수행하던 다른 작업도 함께 중지됩니다."
        )
    }
    public func processStopRequested(_ name: String) -> String {
        value(english: "Asked \(name) to stop.", korean: "\(name)에 종료를 요청했습니다.")
    }
    public var cwdUnavailable: String { value(english: "run location (cwd) unavailable", korean: "실행 위치(cwd) 확인 불가") }
    public var dockerUnavailable: String { value(english: "Docker unavailable", korean: "Docker 사용 불가") }
    public var dockerCouldNotBeRead: String {
        value(english: "Docker could not be read.", korean: "Docker 정보를 읽지 못했습니다.")
    }
    public var unavailableBadge: String { value(english: "UNAVAILABLE", korean: "사용 불가") }
    public var noMappedRunningContainer: String {
        value(english: "No linked Docker container", korean: "연결된 Docker 컨테이너 없음")
    }
    public var dockerAvailableNoMount: String {
        value(
            english: "No running container mounts this folder or was explicitly registered by the repository.",
            korean: "이 폴더를 마운트했거나 저장소가 명시적으로 등록한 실행 컨테이너가 없습니다."
        )
    }
    public var dockerAvailableBadge: String { value(english: "DOCKER AVAILABLE", korean: "DOCKER 사용 가능") }
    public func runtimeMapAccessibility(_ name: String) -> String {
        value(english: "Runtime status for \(name)", korean: "\(name)의 실행 상태")
    }

    public func processLocation(pid: Int32, cwd: String?) -> String {
        let location = cwd ?? cwdUnavailable
        return value(
            english: "PID \(pid) · Run location (cwd): \(location)",
            korean: "PID \(pid) · 실행 위치(cwd): \(location)"
        )
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
        "Runtime Atlas cannot safely stop this process.": "이 프로세스는 안전하게 종료할 수 없습니다.",
        "The process is no longer running from this worktree. Refresh and try again.": "프로세스가 더 이상 이 작업 폴더에서 실행되고 있지 않습니다. 새로고침 후 다시 시도하세요.",
        "The process is no longer listening on the displayed ports. Refresh and try again.": "프로세스가 더 이상 표시된 포트를 열고 있지 않습니다. 새로고침 후 다시 시도하세요.",
        "The process could not be stopped. Check permissions and try again.": "프로세스를 종료하지 못했습니다. 권한을 확인하고 다시 시도하세요.",
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
        "The command session file is damaged; running command buttons may need to be started again.": "명령 세션 파일이 손상되어 실행 중인 명령 버튼을 다시 시작해야 할 수 있습니다."
    ]
}
