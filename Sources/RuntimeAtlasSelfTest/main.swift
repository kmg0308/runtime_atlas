import Darwin
import Foundation
import RuntimeAtlasCore

if CommandLine.arguments.count == 3,
   CommandLine.arguments[1] == "--validate-update-archive" {
    do {
        let archiveURL = URL(fileURLWithPath: CommandLine.arguments[2])
        try UpdateArchiveValidator.validate(archiveURL)
        print("PASS update archive \(archiveURL.lastPathComponent)")
        exit(0)
    } catch {
        fputs("FAIL update archive: \(error)\n", stderr)
        exit(1)
    }
}

private struct AssertionFailure: Error, CustomStringConvertible {
    let description: String
}

private final class SelfTestSuite {
    private(set) var passed = 0
    private(set) var failed = 0

    func run(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            passed += 1
            print("PASS \(name)")
        } catch {
            failed += 1
            fputs("FAIL \(name): \(error)\n", stderr)
        }
    }

    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw AssertionFailure(description: message) }
    }

    func equal<Value: Equatable>(_ actual: Value, _ expected: Value, _ message: String) throws {
        guard actual == expected else {
            throw AssertionFailure(
                description: "\(message) (actual: \(actual), expected: \(expected))"
            )
        }
    }
}

private final class TemporaryDirectory {
    let url: URL

    init(prefix: String = "runtime-atlas-self-test") throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

private enum TestCommandError: Error {
    case failed(String)
}

@discardableResult
private func runGit(_ arguments: [String], in directory: URL? = nil) throws -> CommandResult {
    let result = try CommandExecutor().run(
        executable: ExecutableLocator.git,
        arguments: arguments,
        currentDirectory: directory
    )
    guard result.exitCode == 0 else { throw TestCommandError.failed(result.standardError) }
    return result
}

private func makeGitRepository(in parent: URL, name: String = "repository") throws -> URL {
    let repository = parent.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
    try runGit(["init", "-b", "main", repository.path])
    try Data("fixture\n".utf8).write(to: repository.appendingPathComponent("README.md"))
    try runGit(["-C", repository.path, "add", "README.md"])
    try runGit([
        "-C", repository.path,
        "-c", "user.name=Runtime Atlas Tests",
        "-c", "user.email=runtime-atlas-tests@example.invalid",
        "commit", "-m", "initial"
    ])
    return repository
}

private func makeEvidence(
    kind: EvidenceKind = .command,
    status: EvidenceStatus,
    path: String,
    sha: String,
    endedAt: Date,
    note: String? = nil
) -> EvidenceRecord {
    EvidenceRecord(
        kind: kind,
        status: status,
        worktreePath: path,
        branch: "main",
        sha: sha,
        dirty: false,
        command: kind == .command ? ["/usr/bin/true"] : nil,
        exitCode: kind == .command ? (status == .pass ? 0 : 1) : nil,
        startedAt: endedAt.addingTimeInterval(-1),
        endedAt: endedAt,
        note: note,
        viewport: nil
    )
}

private final class FailureCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ error: Error) {
        lock.lock()
        storage.append(String(describing: error))
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class SignalCapture: @unchecked Sendable {
    private let lock = NSLock()
    private let result: Int32
    private var storage: [(Int32, Int32)] = []

    init(result: Int32 = 0) {
        self.result = result
    }

    func send(pid: Int32, signal: Int32) -> Int32 {
        lock.lock()
        storage.append((pid, signal))
        lock.unlock()
        return result
    }

    var values: [(Int32, Int32)] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func writeUpdateAppBundle(
    in directory: URL,
    name: String,
    bundleName: String = UpdateReleasePolicy.runtimeAtlasAppName,
    bundleIdentifier: String = UpdateReleasePolicy.runtimeAtlasBundleIdentifier,
    executableName: String = UpdateReleasePolicy.runtimeAtlasExecutableName,
    packageType: String = "APPL",
    shortVersion: String = "1.0.0",
    buildVersion: String = "1",
    extraInfoPlistKeys: String = "",
    writeExecutable: Bool = true,
    writeCLIHelper: Bool = true,
    writeActionSupervisor: Bool = true
) throws -> URL {
    let appURL = directory.appendingPathComponent(name, isDirectory: true)
    let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
    let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
    let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
    try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

    let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleIdentifier</key>
        <string>\(bundleIdentifier)</string>
        <key>CFBundleName</key>
        <string>\(bundleName)</string>
        <key>CFBundleExecutable</key>
        <string>\(executableName)</string>
        <key>CFBundlePackageType</key>
        <string>\(packageType)</string>
        <key>CFBundleShortVersionString</key>
        <string>\(shortVersion)</string>
        <key>CFBundleVersion</key>
        <string>\(buildVersion)</string>
        \(extraInfoPlistKeys)
    </dict>
    </plist>
    """
    try infoPlist.write(
        to: contentsURL.appendingPathComponent("Info.plist"),
        atomically: true,
        encoding: .utf8
    )

    if writeExecutable {
        let executableURL = macOSURL.appendingPathComponent(executableName)
        try "#!/bin/sh\nexit 0\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
    }
    if writeCLIHelper {
        let helperURL = helpersURL.appendingPathComponent(UpdateReleasePolicy.runtimeAtlasCLIHelperName)
        try "#!/bin/sh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    }
    if writeActionSupervisor {
        let helperURL = helpersURL.appendingPathComponent(UpdateReleasePolicy.runtimeAtlasActionSupervisorName)
        try "#!/bin/sh\nexit 0\n".write(to: helperURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
    }

    return appURL
}

private func expectUpdateValidationError(
    _ expected: UpdateReleasePolicy.AppBundleValidationError,
    from appURL: URL
) throws {
    do {
        try UpdateReleasePolicy.validateRuntimeAtlasAppBundle(at: appURL)
    } catch let error as UpdateReleasePolicy.AppBundleValidationError {
        guard error == expected else {
            throw AssertionFailure(description: "expected \(expected), received \(error)")
        }
        return
    }
    throw AssertionFailure(description: "expected update bundle validation error \(expected)")
}

private let suite = SelfTestSuite()

suite.run("Git worktree porcelain parser") {
    let output = """
    worktree /tmp/main
    HEAD 1111111111111111111111111111111111111111
    branch refs/heads/main

    worktree /tmp/feature
    HEAD 2222222222222222222222222222222222222222
    branch refs/heads/feature/one

    worktree /tmp/detached
    HEAD 3333333333333333333333333333333333333333
    detached
    prunable gitdir file points to non-existent location

    """
    let worktrees = GitWorktreeParser.parse(output)
    try suite.equal(worktrees.count, 3, "all worktrees should parse")
    try suite.equal(worktrees[0].branch, "main", "normal branch should parse")
    try suite.equal(worktrees[1].branch, "feature/one", "slash branch should parse")
    try suite.require(worktrees[2].detached, "detached HEAD should parse")
    try suite.require(worktrees[2].prunable, "prunable worktree should parse")
}

suite.run("Git clean dirty detached missing and non-Git states") {
    let temporary = try TemporaryDirectory()
    let repository = try makeGitRepository(in: temporary.url)
    let feature = temporary.url.appendingPathComponent("feature", isDirectory: true)
    try runGit(["-C", repository.path, "worktree", "add", "-b", "feature", feature.path])
    let featureCanonical = PathUtilities.canonical(feature.path)

    var inspected = GitInspector().inspectRepository(RepositoryRegistration(path: repository.path))
    try suite.equal(inspected.worktrees.count, 2, "multiple worktrees should be discovered")
    try suite.require(inspected.worktrees.allSatisfy { !$0.dirty }, "fresh worktrees should be clean")

    try Data("dirty\n".utf8).write(to: repository.appendingPathComponent("dirty.txt"))
    try runGit(["-C", feature.path, "checkout", "--detach"])
    inspected = GitInspector().inspectRepository(RepositoryRegistration(path: repository.path))
    try suite.require(
        inspected.worktrees.first { $0.path == repository.path }?.dirty == true,
        "untracked file should mark the worktree dirty"
    )
    try suite.require(
        inspected.worktrees.first { $0.path == featureCanonical }?.detached == true,
        "detached worktree should remain explicit"
    )

    try FileManager.default.removeItem(at: feature)
    inspected = GitInspector().inspectRepository(RepositoryRegistration(path: repository.path))
    let deletedWorktree = inspected.worktrees.first { $0.availability == .unavailable }
    try suite.require(
        deletedWorktree != nil,
        "deleted worktree should be unavailable; found \(inspected.worktrees.map { "\($0.path):\($0.availability.rawValue)" })"
    )

    let missing = GitInspector().inspectRepository(
        RepositoryRegistration(path: temporary.url.appendingPathComponent("missing").path)
    )
    try suite.equal(missing.availability, .unavailable, "missing repository should be unavailable")

    let plain = temporary.url.appendingPathComponent("plain", isDirectory: true)
    try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
    let nonGit = GitInspector().inspectRepository(RepositoryRegistration(path: plain.path))
    try suite.equal(nonGit.availability, .unavailable, "non-Git path should be unavailable")
}

suite.run("lsof IPv4 IPv6 ports and cwd parser") {
    let listening = """
    p42
    cnode
    nTCP *:3000 (LISTEN)
    nTCP 127.0.0.1:4000 (LISTEN)
    p84
    cpostgres
    nTCP [::1]:5432 (LISTEN)
    """
    let processes = LsofParser.parseListeningProcesses(listening)
    try suite.equal(processes.count, 2, "two processes should parse")
    try suite.equal(
        processes[0].ports,
        [ListeningPort(address: "*", port: 3_000), ListeningPort(address: "127.0.0.1", port: 4_000)],
        "IPv4 and wildcard ports should parse"
    )
    try suite.equal(
        processes[1].ports,
        [ListeningPort(address: "[::1]", port: 5_432)],
        "IPv6 port should parse"
    )

    let directories = LsofParser.parseWorkingDirectories("p42\nfcwd\nn/tmp/project\np84\nfcwd\nn/tmp/other\n")
    try suite.equal(directories[42], "/tmp/project", "first cwd should map")
    try suite.equal(directories[84], "/tmp/other", "second cwd should map")

    let noMatchExecutor = CommandExecutor { _, _, _ in
        CommandResult(exitCode: 1, standardOutput: "", standardError: "")
    }
    let noMatches = ProcessDetector(executor: noMatchExecutor).detect()
    try suite.equal(noMatches.availability, .available, "lsof no-match should be an available empty state")
    try suite.equal(noMatches.processes, [], "lsof no-match should contain no processes")
}

suite.run("Process termination revalidates PID cwd and listening ports") {
    let expected = RuntimeProcess(
        pid: 4_242,
        name: "node",
        cwd: "/tmp/project/web",
        ports: [ListeningPort(address: "*", port: 3_000)]
    )
    let available = DiscoveryAvailability.available

    let successfulSignals = SignalCapture()
    let successful = ProcessTerminator(
        detector: { ProcessDiscoveryResult(availability: available, processes: [expected]) },
        signalSender: { successfulSignals.send(pid: $0, signal: $1) },
        runtimeAtlasPID: 9_999
    )
    try successful.terminate(expected, inWorktree: "/tmp/project")
    try suite.equal(successfulSignals.values.count, 1, "a valid target should receive one signal")
    try suite.equal(successfulSignals.values.first?.0, expected.pid, "the displayed PID should receive the signal")
    try suite.equal(successfulSignals.values.first?.1, SIGTERM, "termination must start with SIGTERM")

    let changedCWD = RuntimeProcess(
        pid: expected.pid,
        name: expected.name,
        cwd: "/tmp/other",
        ports: expected.ports
    )
    let changedSignals = SignalCapture()
    let changed = ProcessTerminator(
        detector: { ProcessDiscoveryResult(availability: available, processes: [changedCWD]) },
        signalSender: { changedSignals.send(pid: $0, signal: $1) },
        runtimeAtlasPID: 9_999
    )
    do {
        try changed.terminate(expected, inWorktree: "/tmp/project")
        throw AssertionFailure(description: "a reused PID with another cwd was terminated")
    } catch let error as ProcessTerminationError {
        try suite.equal(error, .processChanged, "a changed process identity should be rejected")
    }
    try suite.equal(changedSignals.values.count, 0, "identity rejection must not send a signal")

    let changedPorts = RuntimeProcess(
        pid: expected.pid,
        name: expected.name,
        cwd: expected.cwd,
        ports: [ListeningPort(address: "*", port: 4_000)]
    )
    let portSignals = SignalCapture()
    let noLongerListening = ProcessTerminator(
        detector: { ProcessDiscoveryResult(availability: available, processes: [changedPorts]) },
        signalSender: { portSignals.send(pid: $0, signal: $1) },
        runtimeAtlasPID: 9_999
    )
    do {
        try noLongerListening.terminate(expected, inWorktree: "/tmp/project")
        throw AssertionFailure(description: "a process no longer owning the displayed port was terminated")
    } catch let error as ProcessTerminationError {
        try suite.equal(error, .noLongerListening, "changed ports should be rejected")
    }
    try suite.equal(portSignals.values.count, 0, "port rejection must not send a signal")

    let failedSignals = SignalCapture(result: -1)
    let permissionFailure = ProcessTerminator(
        detector: { ProcessDiscoveryResult(availability: available, processes: [expected]) },
        signalSender: { failedSignals.send(pid: $0, signal: $1) },
        runtimeAtlasPID: 9_999
    )
    do {
        try permissionFailure.terminate(expected, inWorktree: "/tmp/project")
        throw AssertionFailure(description: "a failed signal was reported as successful")
    } catch let error as ProcessTerminationError {
        try suite.equal(error, .signalFailed, "signal failure should be explicit")
    }

    let selfTarget = RuntimeProcess(
        pid: 4_242,
        name: "RuntimeAtlas",
        cwd: "/tmp/project",
        ports: expected.ports
    )
    do {
        try ProcessTerminator(runtimeAtlasPID: selfTarget.pid)
            .terminate(selfTarget, inWorktree: "/tmp/project")
        throw AssertionFailure(description: "Runtime Atlas attempted to terminate itself")
    } catch let error as ProcessTerminationError {
        try suite.equal(error, .invalidTarget, "the app process must be rejected")
    }
}

suite.run("Local command timeout prevents a stuck refresh") {
    do {
        _ = try CommandExecutor(timeout: 0.1).run(
            executable: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["2"]
        )
        throw AssertionFailure(description: "a stuck local command did not time out")
    } catch CommandExecutionError.timedOut {
        // Expected.
    }
}

suite.run("Docker inspect parser and graceful unavailable states") {
    let fixture = """
    [{"Id":"abc123","Name":"/web","Config":{"Image":"example/web:latest"},
    "Mounts":[{"Source":"/tmp/project","Destination":"/workspace"}],
    "NetworkSettings":{"Ports":{"3000/tcp":[{"HostIp":"127.0.0.1","HostPort":"33000"}],"9229/tcp":null}}}]
    """
    guard let containers = DockerInspectParser.parse(Data(fixture.utf8)) else {
        throw AssertionFailure(description: "valid Docker inspect JSON did not parse")
    }
    try suite.equal(containers.count, 1, "container should parse")
    try suite.equal(containers[0].name, "web", "leading slash should be removed")
    try suite.equal(containers[0].mountSources, ["/tmp/project"], "mount should parse")
    try suite.equal(containers[0].ports.first?.hostPort, 33_000, "published port should parse")
    try suite.equal(
        DockerInspectParser.parse(Data("{".utf8)),
        nil,
        "malformed Docker inspect JSON should be distinguishable from an empty list"
    )
    try suite.equal(
        DockerInspectParser.parse(Data("[{}]".utf8)),
        nil,
        "Docker inspect objects without an ID should be rejected"
    )

    try suite.equal(
        DockerDetector(executable: nil).detect().availability.reason,
        "Docker CLI is not installed.",
        "missing CLI should degrade"
    )
    let daemonExecutor = CommandExecutor { _, _, _ in
        CommandResult(exitCode: 1, standardOutput: "", standardError: "Cannot connect to Docker daemon")
    }
    try suite.equal(
        DockerDetector(executor: daemonExecutor, executable: URL(fileURLWithPath: "/tmp/docker"))
            .detect().availability.reason,
        "Docker daemon is not responding.",
        "stopped daemon should degrade"
    )
    let permissionExecutor = CommandExecutor { _, _, _ in
        CommandResult(exitCode: 1, standardOutput: "", standardError: "permission denied")
    }
    try suite.equal(
        DockerDetector(executor: permissionExecutor, executable: URL(fileURLWithPath: "/tmp/docker"))
            .detect().availability.reason,
        "Docker is unavailable: permission denied.",
        "permission failure should degrade"
    )
    let malformedInspectExecutor = CommandExecutor { _, arguments, _ in
        switch arguments.first {
        case "info":
            return CommandResult(exitCode: 0, standardOutput: "29.0", standardError: "")
        case "ps":
            return CommandResult(exitCode: 0, standardOutput: "abc123\n", standardError: "")
        default:
            return CommandResult(exitCode: 0, standardOutput: "[{}]", standardError: "")
        }
    }
    try suite.equal(
        DockerDetector(
            executor: malformedInspectExecutor,
            executable: URL(fileURLWithPath: "/tmp/docker")
        ).detect().availability.reason,
        "Docker container details could not be parsed.",
        "malformed inspect output should degrade instead of claiming no containers"
    )
    let incompleteInspectExecutor = CommandExecutor { _, arguments, _ in
        switch arguments.first {
        case "info":
            return CommandResult(exitCode: 0, standardOutput: "29.0", standardError: "")
        case "ps":
            return CommandResult(exitCode: 0, standardOutput: "abc123\ndef456\n", standardError: "")
        default:
            return CommandResult(
                exitCode: 0,
                standardOutput: "[{\"Id\":\"abc123\",\"Name\":\"/web\"}]",
                standardError: ""
            )
        }
    }
    try suite.equal(
        DockerDetector(
            executor: incompleteInspectExecutor,
            executable: URL(fileURLWithPath: "/tmp/docker")
        ).detect().availability.reason,
        "Docker container details could not be parsed.",
        "incomplete inspect output should degrade instead of dropping a container"
    )
}

suite.run("Repository registration normalizes a selected subdirectory") {
    let temporary = try TemporaryDirectory()
    let repository = try makeGitRepository(in: temporary.url)
    let nested = repository.appendingPathComponent("Sources/Nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url.appendingPathComponent("data"))
    let store = ConfigurationStore(paths: paths)

    let nestedID = try store.addRepository(path: nested.path)
    let rootID = try store.addRepository(path: repository.path)
    let configuration = try store.load().value
    try suite.equal(nestedID, rootID, "subdirectory and repository root should deduplicate")
    try suite.equal(configuration.repositories.count, 1, "only one repository should be registered")
    try suite.equal(
        configuration.repositories.first?.path,
        PathUtilities.canonical(repository.path),
        "registered path should be the Git top level"
    )
}

suite.run("Runtime process and container mapping") {
    let temporary = try TemporaryDirectory()
    let repository = try makeGitRepository(in: temporary.url)
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url.appendingPathComponent("data"))
    try ConfigurationStore(paths: paths).addRepository(path: repository.path)
    try ConfigurationStore(paths: paths).setDatabaseLabel("manual_fallback", forWorktree: repository.path)
    try RuntimeBindingStore(paths: paths).linkDatabase(
        label: "reported_test",
        worktreePath: repository.path,
        containerName: "database"
    )

    let processExecutor = CommandExecutor { _, arguments, _ in
        if arguments.contains("-iTCP") {
            return CommandResult(
                exitCode: 0,
                standardOutput: "p42\ncnode\nnTCP *:3000 (LISTEN)\n",
                standardError: ""
            )
        }
        return CommandResult(
            exitCode: 0,
            standardOutput: "p42\nfcwd\nn\(repository.path)/Sources\n",
            standardError: ""
        )
    }
    let dockerExecutor = CommandExecutor { _, arguments, _ in
        switch arguments.first {
        case "info":
            return CommandResult(exitCode: 0, standardOutput: "29.0", standardError: "")
        case "ps":
            return CommandResult(exitCode: 0, standardOutput: "abc123\ndb456\n", standardError: "")
        default:
            let json = """
            [{"Id":"abc123","Name":"/web","Config":{"Image":"web"},
            "Mounts":[{"Source":"\(repository.path)","Destination":"/workspace"}],
            "NetworkSettings":{"Ports":{}}},
            {"Id":"db456","Name":"/database","Config":{"Image":"postgres:17-alpine"},
            "Mounts":[{"Name":"shared-data","Destination":"/var/lib/postgresql/data"}],
            "NetworkSettings":{"Ports":{"5432/tcp":[{"HostIp":"127.0.0.1","HostPort":"5432"}]}}}]
            """
            return CommandResult(exitCode: 0, standardOutput: json, standardError: "")
        }
    }
    let status = try StatusService(
        configurationStore: ConfigurationStore(paths: paths),
        evidenceStore: EvidenceStore(paths: paths),
        runtimeBindingStore: RuntimeBindingStore(paths: paths),
        processDetector: ProcessDetector(executor: processExecutor),
        dockerDetector: DockerDetector(
            executor: dockerExecutor,
            executable: URL(fileURLWithPath: "/tmp/docker")
        )
    ).makeStatus()
    guard let worktree = status.repositories.first?.worktrees.first else {
        throw AssertionFailure(description: "mapped worktree is missing")
    }
    try suite.equal(worktree.processes.map(\.pid), [42], "cwd should map process")
    try suite.equal(worktree.containers.map(\.name), ["database", "web"], "mounts and explicit DB bindings should map containers")
    try suite.equal(worktree.databaseLabel, "reported_test", "active binding should override the display label")
    try suite.equal(worktree.manualDatabaseLabel, "manual_fallback", "automatic binding must not mutate the manual fallback")
    try suite.equal(worktree.databaseBinding?.label, "reported_test", "automatic binding source should remain visible")
    try suite.equal(worktree.databaseBinding?.containerName, "database", "DB binding should retain its non-secret container relationship")
}

suite.run("Evidence current statuses and immutable STALE view") {
    let path = "/tmp/project"
    let now = Date()
    let records = [
        makeEvidence(status: .pass, path: path, sha: "current", endedAt: now),
        makeEvidence(status: .fail, path: path, sha: "current", endedAt: now.addingTimeInterval(-1)),
        makeEvidence(kind: .manual, status: .blocked, path: path, sha: "current", endedAt: now.addingTimeInterval(-2)),
        makeEvidence(kind: .manual, status: .pending, path: path, sha: "current", endedAt: now.addingTimeInterval(-3)),
        makeEvidence(status: .pass, path: path, sha: "older", endedAt: now.addingTimeInterval(-4))
    ]
    let overview = EvidenceEvaluator.overview(records: records, worktreePath: path, currentSHA: "current")
    try suite.equal(overview.latestCurrent?.displayStatus, .pass, "latest current evidence should be PASS")
    try suite.equal(
        overview.currentCounts,
        EvidenceCounts(pass: 1, fail: 1, blocked: 1, pending: 1),
        "current counts should preserve all statuses"
    )
    try suite.equal(overview.history.last?.displayStatus, .stale, "old SHA should display STALE")
    try suite.equal(records.last?.status, .pass, "original status must remain immutable")
    try suite.equal(records.last?.sha, "older", "original SHA must remain immutable")
}

suite.run("verify stdout stderr exit code and manual evidence") {
    let temporary = try TemporaryDirectory()
    let repository = try makeGitRepository(in: temporary.url)
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url.appendingPathComponent("data"))
    try ConfigurationStore(paths: paths).addRepository(path: repository.path)
    let evidenceStore = EvidenceStore(paths: paths)

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let failed = try VerificationRunner(evidenceStore: evidenceStore).run(
        command: ["/bin/sh", "-c", "printf atlas-standard-output; printf atlas-standard-error >&2; exit 7"],
        currentDirectory: repository,
        standardOutput: outputPipe.fileHandleForWriting,
        standardError: errorPipe.fileHandleForWriting
    )
    try outputPipe.fileHandleForWriting.close()
    try errorPipe.fileHandleForWriting.close()
    let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let error = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    try suite.equal(failed.exitCode, 7, "verify should preserve failure exit code")
    try suite.equal(output, "atlas-standard-output", "stdout should pass through")
    try suite.equal(error, "atlas-standard-error", "stderr should pass through")
    try suite.equal(failed.record.status, .fail, "nonzero command should record FAIL")

    let passed = try VerificationRunner(evidenceStore: evidenceStore).run(
        command: ["/usr/bin/true"],
        currentDirectory: repository,
        standardOutput: FileHandle.nullDevice,
        standardError: FileHandle.nullDevice
    )
    try suite.equal(passed.exitCode, 0, "verify should preserve success exit code")
    try suite.equal(passed.record.status, .pass, "zero command should record PASS")

    try ManualEvidenceRecorder(evidenceStore: evidenceStore).record(
        kind: .manual,
        status: .blocked,
        note: "Native window unavailable",
        viewport: "980x640",
        currentDirectory: repository
    )
    try ManualEvidenceRecorder(evidenceStore: evidenceStore).record(
        kind: .browser,
        status: .pending,
        note: "Waiting for observation",
        viewport: "1280x800",
        currentDirectory: repository
    )

    try Data("next\n".utf8).write(to: repository.appendingPathComponent("NEXT.md"))
    try runGit(["-C", repository.path, "add", "NEXT.md"])
    try runGit([
        "-C", repository.path,
        "-c", "user.name=Runtime Atlas Tests",
        "-c", "user.email=runtime-atlas-tests@example.invalid",
        "commit", "-m", "next"
    ])
    let emptyProcessExecutor = CommandExecutor { _, _, _ in
        CommandResult(exitCode: 0, standardOutput: "", standardError: "")
    }
    let status = try StatusService(
        configurationStore: ConfigurationStore(paths: paths),
        evidenceStore: evidenceStore,
        runtimeBindingStore: RuntimeBindingStore(paths: paths),
        processDetector: ProcessDetector(executor: emptyProcessExecutor),
        dockerDetector: DockerDetector(executable: nil)
    ).makeStatus()
    guard let overview = status.repositories.first?.worktrees.first?.evidence else {
        throw AssertionFailure(description: "evidence overview is missing")
    }
    try suite.require(overview.history.allSatisfy { $0.displayStatus == .stale }, "SHA change should make all old evidence STALE")
    let originals = try evidenceStore.load().value.records.map(\.status.rawValue).sorted()
    try suite.equal(originals, ["BLOCKED", "FAIL", "PASS", "PENDING"], "persisted evidence statuses must not change")
}

suite.run("Korean English localization and language setting compatibility") {
    try suite.equal(AppLanguage.preferred(for: ["ko-KR"]), .korean, "Korean system language should default to Korean")
    try suite.equal(AppLanguage.preferred(for: ["en-US"]), .english, "English system language should default to English")
    try suite.equal(AppLanguage.preferred(for: []), .english, "unknown system language should safely default to English")

    let english = AtlasCopy(language: .english)
    let korean = AtlasCopy(language: .korean)
    try suite.equal(english.addRepository, "Add Repository", "English copy should be available")
    try suite.equal(korean.addRepository, "저장소 추가", "Korean copy should be available")
    try suite.equal(korean.dockerUnavailable, "Docker 사용 불가", "runtime states should be localized")
    try suite.equal(korean.evidenceKind(.manual), "수동", "evidence kinds should be localized")
    try suite.equal(korean.runtimeMap, "실행 연결", "technical section names should have a plain Korean primary label")
    try suite.equal(english.runtimeMap, "Running Connections", "technical section names should have a plain English primary label")
    try suite.require(korean.detachedHead.contains("detached HEAD"), "plain copy should preserve the exact Git term")
    try suite.require(english.fullSHA.contains("SHA"), "plain copy should preserve the exact code identifier term")
    try suite.require(korean.processLocation(pid: 42, cwd: "/tmp/example").contains("cwd"), "process location should preserve cwd as a secondary term")
    try suite.equal(korean.evidenceDisplayStatusLabel(.stale), "이전 코드 · STALE", "STALE should have a plain localized label")
    try suite.equal(english.evidenceDisplayStatusLabel(.pass), "Passed · PASS", "PASS should have a plain English label")
    try suite.equal(english.checkForUpdates, "Check for Updates", "English update controls should be available")
    try suite.equal(korean.checkForUpdates, "업데이트 확인", "Korean update controls should be available")
    try suite.equal(korean.actions, "명령어", "the repository entry should use command wording")
    try suite.equal(english.actions, "Commands", "English should use command wording")
    try suite.require(korean.actionsSubtitle.contains("모든 작업 폴더"), "repository settings should explain shared definitions")
    try suite.require(korean.worktreeActionsSubtitle.contains("이 작업 폴더"), "worktree commands should explain their run location")
    try suite.equal(korean.commandRunLocation, "실행할 작업 폴더", "the run target picker should be explicit")
    try suite.require(
        korean.updateAvailable("1.2.3").contains("1.2.3"),
        "localized update availability should preserve the version"
    )
    for message in AtlasCopy.localizedCoreMessageKeys {
        try suite.require(
            korean.localizedCoreMessage(message) != message,
            "Korean core message is missing for \(message)"
        )
        try suite.equal(english.localizedCoreMessage(message), message, "English core messages should remain stable")
    }

    let legacyJSON = Data(#"{"schemaVersion":1,"repositories":[],"databaseLabels":{}}"#.utf8)
    let legacyConfiguration = try JSONDecoder().decode(RuntimeAtlasConfiguration.self, from: legacyJSON)
    try suite.equal(legacyConfiguration.appLanguage, nil, "configuration written before language support should still decode")

    let temporary = try TemporaryDirectory()
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url)
    let store = ConfigurationStore(paths: paths)
    let repositoryID = try store.addRepository(path: "/tmp/language-fixture")
    try store.setDatabaseLabel("local_test", forWorktree: "/tmp/language-fixture")
    try store.setAppLanguage(.korean)
    var configuration = try store.load().value
    try suite.equal(configuration.appLanguage, .korean, "Korean choice should persist")
    try suite.equal(configuration.repositories.first?.id, repositoryID, "language save should preserve repositories")
    try suite.equal(configuration.databaseLabels["/tmp/language-fixture"], "local_test", "language save should preserve DB labels")

    try store.setAppLanguage(.english)
    configuration = try store.load().value
    try suite.equal(configuration.appLanguage, .english, "English choice should replace Korean")
}

suite.run("Atomic concurrent storage corruption recovery and privacy") {
    let temporary = try TemporaryDirectory()
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url)

    try suite.equal(try DatabaseLabelValidator.normalized(" refactoring_test "), "refactoring_test", "logical label should normalize")
    do {
        _ = try DatabaseLabelValidator.normalized("postgresql://example.invalid/database")
        throw AssertionFailure(description: "connection string was accepted as a DB label")
    } catch DatabaseLabelError.invalid {
        // Expected.
    }

    let sanitizedCommand = PrivacySanitizer.command([
        "tool", "--api-key", "sensitive-sentinel",
        "PASSWORD=sensitive-sentinel",
        "postgresql://example.invalid/database"
    ])
    try suite.equal(
        sanitizedCommand,
        ["tool", "--api-key", "<redacted>", "PASSWORD=<redacted>", "<redacted-url>"],
        "credential-shaped command arguments should redact"
    )
    try suite.equal(
        PrivacySanitizer.command([
            "/bin/sh", "-c", "curl https://example.invalid -H 'Authorization: Bearer sensitive-sentinel'"
        ]),
        ["/bin/sh", "-c", "<redacted-shell-script>"],
        "shell command bodies should never be persisted"
    )
    try suite.equal(
        PrivacySanitizer.command([
            "curl", "-H", "Authorization: Bearer sensitive-sentinel",
            "--user=example:sensitive-sentinel", "--url=https://example.invalid/private"
        ]),
        ["curl", "-H", "<redacted>", "--user=<redacted>", "--url=<redacted-url>"],
        "header, user, and embedded URL arguments should redact"
    )
    let sanitizedNote = PrivacySanitizer.note("Checked https://example.invalid/path token=sensitive-sentinel")
    try suite.require(!sanitizedNote.contains("example.invalid"), "note URL should redact")
    try suite.require(!sanitizedNote.contains("sensitive-sentinel"), "note credential should redact")
    let headerNote = PrivacySanitizer.note("Authorization: Bearer sensitive-sentinel")
    try suite.require(!headerNote.contains("sensitive-sentinel"), "authorization header notes should redact")

    let failures = FailureCollector()
    DispatchQueue.concurrentPerform(iterations: 60) { index in
        do {
            try EvidenceStore(paths: paths).append(
                makeEvidence(
                    status: index.isMultiple(of: 2) ? .pass : .fail,
                    path: "/tmp/project",
                    sha: "sha",
                    endedAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        } catch {
            failures.append(error)
        }
    }
    try suite.equal(failures.values, [], "concurrent appends should not fail")
    let document = try EvidenceStore(paths: paths).load().value
    try suite.equal(document.records.count, 60, "concurrent appends should not lose data")
    try suite.equal(Set(document.records.map(\.id)).count, 60, "records should stay unique")
    _ = try JSONSerialization.jsonObject(with: Data(contentsOf: paths.evidenceFile))

    let mode = try FileManager.default.attributesOfItem(atPath: paths.evidenceFile.path)[.posixPermissions] as? NSNumber
    try suite.equal(mode?.intValue, 0o600, "evidence file should be user-only")
    let directoryMode = try FileManager.default.attributesOfItem(atPath: paths.directory.path)[.posixPermissions] as? NSNumber
    try suite.equal(directoryMode?.intValue, 0o700, "local data directory should be user-only")

    try Data("{".utf8).write(to: paths.configurationFile)
    let damaged = try ConfigurationStore(paths: paths).load()
    try suite.require(damaged.recoveryNotice != nil, "damaged configuration should report a notice")
    let recoveredRepositoryID = try ConfigurationStore(paths: paths).addRepository(path: "/tmp/project")
    let recovered = try ConfigurationStore(paths: paths).load()
    try suite.require(recovered.recoveryNotice == nil, "next save should recover configuration")
    let preserved = try FileManager.default.contentsOfDirectory(atPath: paths.directory.path)
        .filter { $0.hasPrefix("configuration.json.corrupt-") }
    try suite.equal(preserved.count, 1, "damaged source should be preserved")
    _ = try JSONSerialization.jsonObject(with: Data(contentsOf: paths.configurationFile))

    try ConfigurationStore(paths: paths).setDatabaseLabel("refactoring_test", forWorktree: "/tmp/project/nested")
    try ConfigurationStore(paths: paths).removeRepository(id: recoveredRepositoryID)
    let afterRemoval = try ConfigurationStore(paths: paths).load().value
    try suite.require(afterRemoval.databaseLabels.isEmpty, "repository removal should clear labels under its root")
}

suite.run("Runtime DB binding ownership, liveness, and atomic storage") {
    let temporary = try TemporaryDirectory(prefix: "runtime-atlas-bindings")
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url)
    let store = RuntimeBindingStore(paths: paths)
    let worktree = "/tmp/runtime-atlas-binding-worktree"

    let older = try store.linkDatabase(
        label: "older_active",
        worktreePath: worktree,
        ownerPID: 101,
        registeredAt: Date(timeIntervalSince1970: 1)
    )
    _ = try store.linkDatabase(
        label: "newer_stopped",
        worktreePath: worktree,
        ownerPID: 202,
        registeredAt: Date(timeIntervalSince1970: 2)
    )
    let loaded = try store.load().value.records
    let active = RuntimeBindingEvaluator.activeDatabaseBinding(
        records: loaded,
        worktreePath: worktree,
        processIsRunning: { $0 == 101 }
    )
    try suite.equal(active?.id, older.id, "a stopped newer owner must not hide the active session")

    try store.unlinkDatabase(worktreePath: worktree, ownerPID: 101)
    try suite.equal(try store.load().value.records.map(\.ownerPID), [202], "owner-scoped unlink should preserve parallel sessions")
    try store.unlinkDatabase(worktreePath: worktree)
    let afterFullUnlink = try store.load().value.records
    try suite.require(afterFullUnlink.isEmpty, "path-scoped unlink should remove all sessions")

    do {
        _ = try store.linkDatabase(label: "postgresql://example.invalid/private", worktreePath: worktree)
        throw AssertionFailure(description: "a DB URL was accepted as a runtime binding label")
    } catch DatabaseLabelError.invalid {
        // Expected.
    }

    do {
        _ = try store.linkDatabase(label: "safe_label", worktreePath: worktree, containerName: "https://example.invalid/private")
        throw AssertionFailure(description: "a URL was accepted as a container name")
    } catch RuntimeBindingError.invalidContainerName {
        // Expected.
    }

    let failures = FailureCollector()
    DispatchQueue.concurrentPerform(iterations: 20) { index in
        do {
            _ = try RuntimeBindingStore(paths: paths).linkDatabase(
                label: "parallel_\(index)",
                worktreePath: worktree,
                ownerPID: Int32(index + 1)
            )
        } catch {
            failures.append(error)
        }
    }
    try suite.equal(failures.values, [], "concurrent runtime binding writes should not fail")
    try suite.equal(try store.load().value.records.count, 20, "concurrent runtime binding writes should not lose sessions")
    _ = try JSONSerialization.jsonObject(with: Data(contentsOf: paths.runtimeBindingsFile))
}

suite.run("Update version, commit, asset, and app bundle policy") {
    try suite.require(
        UpdateReleasePolicy.compareVersions("999999999999999999999999.0.0", "2.0.0") == .orderedDescending,
        "large numeric version parts should not overflow"
    )
    try suite.require(
        UpdateReleasePolicy.compareVersions("1.10.0", "1.2.999") == .orderedDescending,
        "version parts should compare numerically"
    )
    try suite.equal(UpdateReleasePolicy.normalizedVersion("v0.1.7"), "0.1.7", "v prefix should normalize")

    let branchRelease = ReleaseInfo(
        version: "1.0.0",
        displayName: "Runtime Atlas 1.0.0",
        zipURL: URL(string: "https://github.com/kmg0308/runtime_atlas/releases/download/v1.0.0/RuntimeAtlas.zip")!,
        htmlURL: nil,
        targetCommitish: "main"
    )
    try suite.require(
        !UpdateAvailability(
            currentVersion: "1.0.0",
            installedBuildCommit: "abcdef1",
            release: branchRelease
        ).isAvailable,
        "a branch target should not force a same-version update"
    )

    let differentCommitRelease = ReleaseInfo(
        version: "1.0.0",
        displayName: "Runtime Atlas 1.0.0",
        zipURL: branchRelease.zipURL,
        htmlURL: nil,
        targetCommitish: "1234567890abcdef"
    )
    try suite.require(
        UpdateAvailability(
            currentVersion: "1.0.0",
            installedBuildCommit: "abcdef1",
            release: differentCommitRelease
        ).isAvailable,
        "a different release commit should update even at the same version"
    )

    for name in ["RuntimeAtlas.zip", "runtimeatlas-0.1.7.zip", "RuntimeAtlas-2026-07-21.zip"] {
        try suite.require(
            UpdateReleasePolicy.isInstallableRuntimeAtlasZipAssetName(name),
            "release ZIP should accept \(name)"
        )
    }
    for name in ["source.zip", "runtimeatlas-source.zip", "runtimeatlas-latest.zip", "RuntimeAtlas.pkg"] {
        try suite.require(
            !UpdateReleasePolicy.isInstallableRuntimeAtlasZipAssetName(name),
            "release ZIP should reject \(name)"
        )
    }
    try suite.equal(
        UpdateReleasePolicy.runtimeAtlasZipDownloadName(version: "v1.2.3"),
        "RuntimeAtlas-1.2.3.zip",
        "download name should normalize a v-prefixed version"
    )
    try suite.equal(
        UpdateReleasePolicy.runtimeAtlasZipDownloadName(version: "../"),
        "RuntimeAtlas.zip",
        "empty sanitized versions should use the fixed ZIP name"
    )

    let temporary = try TemporaryDirectory(prefix: "runtime-atlas-update-policy")
    let validApp = try writeUpdateAppBundle(in: temporary.url, name: "RuntimeAtlas.app")
    try UpdateReleasePolicy.validateRuntimeAtlasAppBundle(at: validApp)

    let wrongIdentity = try writeUpdateAppBundle(
        in: temporary.url,
        name: "WrongIdentity.app",
        bundleIdentifier: "com.example.other"
    )
    try expectUpdateValidationError(
        .invalidBundleIdentity(bundleIdentifier: "com.example.other", executable: "RuntimeAtlas"),
        from: wrongIdentity
    )

    let menuBarOnly = try writeUpdateAppBundle(
        in: temporary.url,
        name: "MenuBarOnly.app",
        extraInfoPlistKeys: "<key>LSUIElement</key>\n    <true/>"
    )
    try expectUpdateValidationError(.menuBarOnlyApp, from: menuBarOnly)

    let missingExecutable = try writeUpdateAppBundle(
        in: temporary.url,
        name: "MissingExecutable.app",
        writeExecutable: false
    )
    try expectUpdateValidationError(.missingExecutable, from: missingExecutable)

    let missingHelper = try writeUpdateAppBundle(
        in: temporary.url,
        name: "MissingHelper.app",
        writeCLIHelper: false
    )
    try expectUpdateValidationError(.missingCLIHelper, from: missingHelper)

    let missingSupervisor = try writeUpdateAppBundle(
        in: temporary.url,
        name: "MissingSupervisor.app",
        writeActionSupervisor: false
    )
    try expectUpdateValidationError(.missingActionSupervisor, from: missingSupervisor)
}

suite.run("Custom action validation, safe expansion, and worktree input") {
    let repositoryID = UUID()
    let worktree = "/tmp/runtime atlas/worktree"
    let action = CustomActionDefinition(
        repositoryID: repositoryID,
        name: "Remove worktree",
        commandTemplate: "npm run worktree:remove -- {{target}} {{deleteBranch}}",
        risk: .destructive,
        workingDirectory: .repositoryRoot,
        effects: ["Deletes the selected worktree"],
        inputs: [
            CustomActionInputDefinition(key: "target", label: "Worktree", kind: .worktree),
            CustomActionInputDefinition(key: "deleteBranch", label: "Delete branch", kind: .flag, flagArgument: "--delete-branch")
        ]
    )
    let plan = try CustomActionPlanner.plan(
        action: action,
        values: ["target": worktree, "deleteBranch": "true"],
        selectedWorktree: worktree,
        repositoryRoot: "/tmp/runtime atlas",
        availableWorktrees: [worktree]
    )
    try suite.equal(plan.executable, "npm", "the first token should be the executable")
    try suite.equal(
        plan.arguments,
        ["run", "worktree:remove", "--", worktree, "--delete-branch"],
        "worktree paths and flags should remain separate arguments"
    )
    try suite.equal(plan.currentDirectory, "/tmp/runtime atlas", "repository root should be selected")
    try suite.require(plan.displayCommand.contains("'/tmp/runtime atlas/worktree'"), "display command should quote spaces")

    for unsafe in [
        "npm run dev && touch /tmp/no", "npm run dev | tee out", "echo $(whoami)", "echo `whoami`",
        "/bin/sh -c 'echo ok; touch /tmp/no'", "/usr/bin/env zsh -lc 'echo ok'"
    ] {
        let unsafeAction = CustomActionDefinition(repositoryID: repositoryID, name: "Unsafe", commandTemplate: unsafe)
        do {
            try CustomActionPlanner.validate(unsafeAction)
            throw AssertionFailure(description: "unsafe command was accepted: \(unsafe)")
        } catch is CustomActionError {
            // Expected.
        }
    }
    for sensitive in ["curl https://example.invalid/private"] {
        let sensitiveAction = CustomActionDefinition(repositoryID: repositoryID, name: "Sensitive", commandTemplate: sensitive)
        do {
            try CustomActionPlanner.validate(sensitiveAction)
            throw AssertionFailure(description: "sensitive action text was accepted")
        } catch is CustomActionError {
            // Expected.
        }
    }
}

suite.run("Custom action configuration is backward compatible and atomic") {
    let temporary = try TemporaryDirectory(prefix: "runtime-atlas-actions")
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url)
    let legacy = """
    {"schemaVersion":1,"repositories":[],"databaseLabels":{},"appLanguage":"ko"}
    """
    try legacy.write(to: paths.configurationFile, atomically: true, encoding: .utf8)
    let store = ConfigurationStore(paths: paths, repositoryRootResolver: { $0 })
    let loaded = try store.load().value
    try suite.equal(loaded.customActions, [], "legacy configuration should decode without actions")
    try suite.equal(loaded.worktreeOrderByRepository, [:], "legacy configuration should decode without a saved worktree order")

    let repositoryID = try store.addRepository(path: "/tmp/action-repository")
    let action = CustomActionDefinition(
        repositoryID: repositoryID,
        name: "Start local server",
        commandTemplate: "npm run dev",
        kind: .session
    )
    try store.saveCustomAction(action)
    let saved = try store.load().value
    try suite.equal(saved.schemaVersion, 2, "saving an action should upgrade configuration schema")
    try suite.equal(saved.customActions, [action], "action should round-trip")
    try suite.equal(
        WorktreeOrderIdentity.key(branch: "feature/one", detached: false, sha: "abc"),
        "branch:feature/one",
        "branch identity should remain portable across local paths"
    )
    try suite.equal(
        WorktreeOrderIdentity.key(branch: nil, detached: true, sha: "abc123"),
        "detached:abc123",
        "detached worktrees should fall back to their SHA"
    )
    try store.setWorktreeOrder(
        repositoryID: repositoryID,
        orderedKeys: ["branch:feature", "branch:main", "branch:feature"]
    )
    let reordered = try store.load().value
    try suite.equal(reordered.schemaVersion, 3, "saving worktree order should upgrade configuration schema")
    try suite.equal(
        reordered.worktreeOrderByRepository[repositoryID.uuidString],
        ["branch:feature", "branch:main"],
        "saved order should be stable and deduplicated"
    )
    try store.removeRepository(id: repositoryID)
    let removed = try store.load().value
    try suite.equal(removed.customActions, [], "removing a repository should remove its action definitions")
    try suite.equal(removed.worktreeOrderByRepository, [:], "removing a repository should remove its saved worktree order")
}

suite.run("Command sessions persist atomically and require supervisor identity") {
    let temporary = try TemporaryDirectory(prefix: "runtime-atlas-action-sessions")
    let paths = RuntimeAtlasPaths(baseDirectory: temporary.url)
    let store = ActionSessionStore(paths: paths)
    let token = UUID()
    let record = ActionSessionRecord(
        actionID: UUID(),
        worktreePath: "/tmp/runtime-atlas-session",
        supervisorPID: 4242,
        identityToken: token,
        startedAt: Date(timeIntervalSince1970: 123)
    )
    try store.upsert(record)
    try suite.equal(try store.load().value.sessions, [record], "a running session should round-trip")

    let matching = "/Applications/RuntimeAtlas.app/Contents/Helpers/runtime-atlas-supervisor --session-id \(token.uuidString) --cwd /tmp/runtime-atlas-session -- npm run dev"
    try suite.require(ActionSessionMatcher.matches(record, commandLine: matching), "the exact session token should restore")
    try suite.require(
        !ActionSessionMatcher.matches(record, commandLine: matching.replacingOccurrences(of: token.uuidString, with: UUID().uuidString)),
        "a reused PID with another session token must not restore"
    )

    let legacy = ActionSessionRecord(
        actionID: UUID(),
        worktreePath: "/tmp/runtime-atlas-session",
        supervisorPID: 4343,
        identityToken: nil
    )
    try suite.require(
        ActionSessionMatcher.matches(
            legacy,
            commandLine: "/path/runtime-atlas-supervisor --cwd /tmp/runtime-atlas-session -- npm run dev"
        ),
        "a legacy supervisor should be recognized by its exact worktree"
    )
    try store.remove(id: record.id)
    try suite.equal(try store.load().value.sessions, [], "stopped sessions should be removed")

    try Data("{".utf8).write(to: paths.actionSessionsFile)
    let damaged = try store.load()
    try suite.require(damaged.recoveryNotice != nil, "damaged session state should recover without crashing")
}

suite.run("Stable status JSON schema") {
    let status = AtlasStatus(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        processDiscovery: .available,
        dockerDiscovery: DiscoveryAvailability(state: .unavailable, reason: "Docker CLI is not installed."),
        notices: [],
        repositories: []
    )
    let data = try StatusJSONEncoder.encode(status)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw AssertionFailure(description: "status JSON root is not an object")
    }
    try suite.equal(object["schemaVersion"] as? Int, 1, "schema version should be stable")
    for key in ["generatedAt", "processDiscovery", "dockerDiscovery", "notices", "repositories"] {
        try suite.require(object[key] != nil, "status JSON is missing \(key)")
    }
}

print("RuntimeAtlasSelfTest: \(suite.passed) passed, \(suite.failed) failed")
exit(suite.failed == 0 ? 0 : 1)
