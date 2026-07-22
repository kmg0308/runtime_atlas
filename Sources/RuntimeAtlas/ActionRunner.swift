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
    var refreshHandler: (() -> Void)?

    func state(for action: CustomActionDefinition, worktreePath: String) -> ActionRunState? {
        states[ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))]
    }

    func isRunning(_ action: CustomActionDefinition, worktreePath: String) -> Bool {
        guard let phase = state(for: action, worktreePath: worktreePath)?.phase else { return false }
        return phase == .running || phase == .stopping
    }

    func start(action: CustomActionDefinition, plan: CustomActionPlan, worktreePath: String) throws {
        let key = ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))
        guard processes[key] == nil else { return }

        let process = Process()
        process.executableURL = try supervisorURL()
        process.arguments = ["--cwd", plan.currentDirectory, "--", plan.executable] + plan.arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        states[key] = ActionRunState(phase: .running, output: "", displayCommand: plan.displayCommand, startedAt: Date())
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
                self?.finish(key: key, exitCode: process.terminationStatus, tail: tail)
            }
        }

        do { try process.run() }
        catch {
            processes.removeValue(forKey: key)
            states[key] = ActionRunState(
                phase: .failed(71), output: error.localizedDescription,
                displayCommand: plan.displayCommand, startedAt: Date()
            )
            throw error
        }
    }

    func stop(action: CustomActionDefinition, worktreePath: String) {
        let key = ActionRunKey(actionID: action.id, worktreePath: PathUtilities.canonical(worktreePath))
        guard let process = processes[key], process.isRunning else { return }
        states[key]?.phase = .stopping
        Darwin.kill(-process.processIdentifier, SIGTERM)
        let pid = process.processIdentifier
        Task.detached {
            try? await Task.sleep(for: .seconds(3))
            if Darwin.kill(pid, 0) == 0 { Darwin.kill(-pid, SIGKILL) }
        }
    }

    func stopAll() {
        for process in processes.values where process.isRunning {
            Darwin.kill(-process.processIdentifier, SIGTERM)
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
        state.output += PrivacySanitizer.note(text)
        if state.output.count > 32_000 { state.output = String(state.output.suffix(32_000)) }
        states[key] = state
    }

    private func finish(key: ActionRunKey, exitCode: Int32, tail: String) {
        append(tail, to: key)
        processes.removeValue(forKey: key)
        let wasStopping = states[key]?.phase == .stopping
        states[key]?.phase = wasStopping ? .stopped : (exitCode == 0 ? .succeeded : .failed(exitCode))
        refreshHandler?()
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
