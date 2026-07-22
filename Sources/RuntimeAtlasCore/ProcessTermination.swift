import Darwin
import Foundation

public enum ProcessTerminationError: LocalizedError, Equatable, Sendable {
    case invalidTarget
    case processChanged
    case noLongerListening
    case signalFailed

    public var errorDescription: String? {
        switch self {
        case .invalidTarget:
            return "Runtime Atlas cannot safely stop this process."
        case .processChanged:
            return "The process is no longer running from this worktree. Refresh and try again."
        case .noLongerListening:
            return "The process is no longer listening on the displayed ports. Refresh and try again."
        case .signalFailed:
            return "The process could not be stopped. Check permissions and try again."
        }
    }
}

public struct ProcessTerminator: Sendable {
    public typealias Detector = @Sendable () -> ProcessDiscoveryResult
    public typealias SignalSender = @Sendable (_ pid: Int32, _ signal: Int32) -> Int32

    private let detector: Detector
    private let signalSender: SignalSender
    private let runtimeAtlasPID: Int32

    public init(
        detector: @escaping Detector = { ProcessDetector().detect() },
        signalSender: @escaping SignalSender = { Darwin.kill($0, $1) },
        runtimeAtlasPID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) {
        self.detector = detector
        self.signalSender = signalSender
        self.runtimeAtlasPID = runtimeAtlasPID
    }

    public func terminate(_ expected: RuntimeProcess, inWorktree worktreePath: String) throws {
        guard expected.pid > 1,
              expected.pid != runtimeAtlasPID,
              !expected.ports.isEmpty,
              let expectedCWD = expected.cwd,
              PathUtilities.isSameOrDescendant(expectedCWD, of: worktreePath) else {
            throw ProcessTerminationError.invalidTarget
        }

        let discovery = detector()
        guard discovery.availability.state == .available,
              let current = discovery.processes.first(where: { $0.pid == expected.pid }),
              current.name == expected.name,
              let currentCWD = current.cwd,
              PathUtilities.canonical(currentCWD) == PathUtilities.canonical(expectedCWD),
              PathUtilities.isSameOrDescendant(currentCWD, of: worktreePath) else {
            throw ProcessTerminationError.processChanged
        }

        guard Set(expected.ports).isSubset(of: Set(current.ports)) else {
            throw ProcessTerminationError.noLongerListening
        }

        guard signalSender(expected.pid, SIGTERM) == 0 else {
            throw ProcessTerminationError.signalFailed
        }
    }
}
