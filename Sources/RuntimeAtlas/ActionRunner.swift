import Darwin
import Foundation
import RuntimeAtlasCore

enum ActionRunPhase: Equatable {
    case running
    case stopping
    case succeeded
    case stopped
    case failed(Int32)
}

struct ActionRunKey: Hashable {
    let actionID: UUID
    let worktreePath: String
}

struct ActionRunState: Equatable {
    var phase: ActionRunPhase
    var output: String
    var displayCommand: String
    var startedAt: Date
}

@MainActor
final class ActionRunner: ObservableObject {
    @Published private(set) var states: [ActionRunKey: ActionRunState] = [:]
    private var processes: [ActionRunKey: Process] = [:]
    private var sessions: [ActionRunKey: ActionSessionRecord] = [:]
    private let sessionStore: ActionSessionStore
    var refreshHandler: (() -> Void)?

    init(sessionStore: ActionSessionStore = ActionSessionStore()) {
        self.sessionStore = sessionStore
    }

    func state(for action: CustomActionDefinition, worktreePath: String) -> ActionRunState? {
        states[ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))]
    }

    func isRunning(_ action: CustomActionDefinition, worktreePath: String) -> Bool {
        guard let phase = state(for: action, worktreePath: worktreePath)?.phase else { return false }
        return phase == .running || phase == .stopping
    }

    func start(action: CustomActionDefinition, plan: CustomActionPlan, worktreePath: String) throws {
        let key = ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))
        guard processes[key] == nil, sessions[key] == nil else { return }

        let startedAt = Date()
        let process = Process()
        let identityToken = UUID()
        process.executableURL = try supervisorURL()
        process.arguments = [
            "--session-id", identityToken.uuidString,
            "--cwd", plan.currentDirectory, "--", plan.executable
        ] + plan.arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        states[key] = ActionRunState(phase: .running, output: "", displayCommand: plan.displayCommand, startedAt: startedAt)
        processes[key] = process

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.append(text, to: key) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.append(text, to: key) }
        }
        process.terminationHandler = { [weak self] process in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = outputPipe.fileHandleForReading.readDataToEndOfFile()
                + errorPipe.fileHandleForReading.readDataToEndOfFile()
            let tail = String(decoding: remaining, as: UTF8.self)
            Task { @MainActor [weak self] in
                self?.finish(
                    key: key,
                    exitCode: process.terminationStatus,
                    tail: tail
                )
            }
        }

        do {
            try process.run()
            if action.kind == .session {
                let record = ActionSessionRecord(
                    actionID: action.id,
                    worktreePath: key.worktreePath,
                    supervisorPID: process.processIdentifier,
                    identityToken: identityToken,
                    startedAt: states[key]?.startedAt ?? Date()
                )
                do {
                    try sessionStore.upsert(record)
                    sessions[key] = record
                } catch {
                    Darwin.kill(-process.processIdentifier, SIGTERM)
                    throw error
                }
            }
        }
        catch {
            processes.removeValue(forKey: key)
            sessions.removeValue(forKey: key)
            states[key] = ActionRunState(
                phase: .failed(71), output: error.localizedDescription,
                displayCommand: plan.displayCommand, startedAt: Date()
            )
            throw error
        }
    }

    func stop(action: CustomActionDefinition, worktreePath: String) {
        let key = ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))
        let pid: Int32
        if let process = processes[key], process.isRunning {
            pid = process.processIdentifier
        } else if let session = sessions[key], Self.processIsRunning(session.supervisorPID) {
            pid = session.supervisorPID
        } else {
            removeSession(for: key)
            return
        }
        states[key]?.phase = .stopping
        Darwin.kill(-pid, SIGTERM)
        Task.detached {
            try? await Task.sleep(for: .seconds(3))
            if Self.processIsRunning(pid) { Darwin.kill(-pid, SIGKILL) }
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run { [weak self] in
                guard let self, self.processes[key] == nil else { return }
                self.states[key]?.phase = .stopped
                self.removeSession(for: key)
                self.refreshHandler?()
            }
        }
    }

    func stopAll() {
        let pids = Set(processes.values.filter(\.isRunning).map(\.processIdentifier))
            .union(sessions.values.map(\.supervisorPID))
        for pid in pids where Self.processIsRunning(pid) {
            Darwin.kill(-pid, SIGTERM)
        }
    }

    func reconcile(actions: [CustomActionDefinition], repositories: [RepositoryStatus]) {
        let actionByID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
        let processLines = Self.supervisorProcesses()
        let commandByPID = Dictionary(uniqueKeysWithValues: processLines.map { ($0.pid, $0.command) })
        let loaded = (try? sessionStore.load().value.sessions) ?? []
        var active: [ActionSessionRecord] = []

        for record in loaded {
            guard let action = actionByID[record.actionID],
                  let command = commandByPID[record.supervisorPID],
                  ActionSessionMatcher.matches(record, commandLine: command) else { continue }
            active.append(record)
            restore(record, action: action)
        }

        let activePIDs = Set(active.map(\.supervisorPID))
        for process in processLines where !activePIDs.contains(process.pid) {
            guard let adopted = legacySession(
                pid: process.pid,
                commandLine: process.command,
                actions: actions,
                repositories: repositories
            ) else { continue }
            active.append(adopted.record)
            restore(adopted.record, action: adopted.action)
        }

        try? sessionStore.replace(with: active)
        let activeKeys = Set(active.map {
            ActionRunKey(actionID: $0.actionID, worktreePath: PathUtilities.canonical($0.worktreePath))
        })
        for key in sessions.keys where !activeKeys.contains(key) && processes[key] == nil {
            sessions.removeValue(forKey: key)
            if states[key]?.phase == .running || states[key]?.phase == .stopping {
                states[key]?.phase = .stopped
            }
        }
    }

    func stop(actions: [CustomActionDefinition], worktrees: [WorktreeStatus]) {
        for action in actions {
            for worktree in worktrees where isRunning(action, worktreePath: worktree.path) {
                stop(action: action, worktreePath: worktree.path)
            }
        }
    }

    private func append(_ text: String, to key: ActionRunKey) {
        guard var state = states[key] else { return }
        state.output += PrivacySanitizer.text(text)
        if state.output.count > 32_000 { state.output = String(state.output.suffix(32_000)) }
        states[key] = state
    }

    private func finish(key: ActionRunKey, exitCode: Int32, tail: String) {
        append(tail, to: key)
        processes.removeValue(forKey: key)
        removeSession(for: key)
        let wasStopping = states[key]?.phase == .stopping
        states[key]?.phase = wasStopping ? .stopped : (exitCode == 0 ? .succeeded : .failed(exitCode))
        refreshHandler?()
    }

    private func restore(_ record: ActionSessionRecord, action: CustomActionDefinition) {
        let key = ActionRunKey(actionID: record.actionID, worktreePath: PathUtilities.canonical(record.worktreePath))
        sessions[key] = record
        states[key] = ActionRunState(
            phase: .running,
            output: states[key]?.output ?? "",
            displayCommand: action.commandTemplate,
            startedAt: record.startedAt
        )
    }

    private func removeSession(for key: ActionRunKey) {
        guard let record = sessions.removeValue(forKey: key) else { return }
        try? sessionStore.remove(id: record.id)
    }

    private func legacySession(
        pid: Int32,
        commandLine: String,
        actions: [CustomActionDefinition],
        repositories: [RepositoryStatus]
    ) -> (record: ActionSessionRecord, action: CustomActionDefinition)? {
        for repository in repositories {
            let repositoryActions = actions.filter {
                $0.repositoryID == repository.id && $0.kind == .session && $0.inputs.isEmpty
            }
            for action in repositoryActions {
                for worktree in repository.worktrees where worktree.availability == .available {
                    guard let plan = try? CustomActionPlanner.plan(
                        action: action,
                        values: [:],
                        selectedWorktree: worktree.path,
                        repositoryRoot: repository.path,
                        availableWorktrees: repository.worktrees.map(\.path)
                    ) else { continue }
                    let signature = "--cwd \(plan.currentDirectory) -- \(plan.displayCommand)"
                    guard commandLine.contains(signature) else { continue }
                    return (
                        ActionSessionRecord(
                            actionID: action.id,
                            worktreePath: worktree.path,
                            supervisorPID: pid,
                            identityToken: nil
                        ),
                        action
                    )
                }
            }
        }
        return nil
    }

    private static func supervisorProcesses() -> [(pid: Int32, command: String)] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command=", "-ww"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let data: Data
        do {
            try process.run()
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
        } catch { return [] }
        guard process.terminationStatus == 0 else { return [] }
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
                guard let separator = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }),
                      let pid = Int32(trimmed[..<separator]) else { return nil }
                let command = trimmed[separator...].drop(while: { $0 == " " || $0 == "\t" })
                guard command.contains("runtime-atlas-supervisor") else { return nil }
                return (pid, String(command))
            }
    }

    private nonisolated static func processIsRunning(_ pid: Int32) -> Bool {
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private func supervisorURL() throws -> URL {
        if let helper = Bundle.main.url(forAuxiliaryExecutable: "runtime-atlas-supervisor") { return helper }
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/runtime-atlas-supervisor")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        let sibling = Bundle.main.executableURL?.deletingLastPathComponent()
            .appendingPathComponent("runtime-atlas-supervisor")
        if let sibling, FileManager.default.isExecutableFile(atPath: sibling.path) { return sibling }
        throw CocoaError(.executableNotLoadable)
    }
}

private extension Data {
    static func + (lhs: Data, rhs: Data) -> Data {
        var result = lhs
        result.append(rhs)
        return result
    }
}
