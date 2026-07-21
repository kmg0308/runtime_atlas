import Darwin
import Foundation

public struct CommandResult: Equatable, Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public enum CommandExecutionError: LocalizedError, Sendable {
    case couldNotLaunch
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .couldNotLaunch:
            return "A required local command could not be launched."
        case .timedOut:
            return "A required local command did not respond in time."
        }
    }
}

public struct CommandExecutor: Sendable {
    public typealias Handler = @Sendable (URL, [String], URL?) throws -> CommandResult
    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public init(timeout: TimeInterval = 10) {
        let boundedTimeout = max(0.1, timeout)
        handler = { executable, arguments, currentDirectory in
            try Self.runProcess(
                executable: executable,
                arguments: arguments,
                currentDirectory: currentDirectory,
                timeout: boundedTimeout
            )
        }
    }

    public func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil
    ) throws -> CommandResult {
        try handler(executable, arguments, currentDirectory)
    }

    private static func runProcess(
        executable: URL,
        arguments: [String],
        currentDirectory: URL?,
        timeout: TimeInterval
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let output = LockedData()
        let error = LockedData()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            error.append(handle.availableData)
        }
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in termination.signal() }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw CommandExecutionError.couldNotLaunch
        }

        if termination.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning {
                process.terminate()
                if termination.wait(timeout: .now() + 0.5) == .timedOut,
                   process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                    _ = termination.wait(timeout: .now() + 0.5)
                }
            }
            process.terminationHandler = nil
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
            throw CommandExecutionError.timedOut
        }

        process.terminationHandler = nil
        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        output.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        error.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        return CommandResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: output.value, as: UTF8.self),
            standardError: String(decoding: error.value, as: UTF8.self)
        )
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

public enum ExecutableLocator {
    public static let git = URL(fileURLWithPath: "/usr/bin/git")
    public static let lsof = URL(fileURLWithPath: "/usr/sbin/lsof")

    public static func docker(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        if let path = environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                    .appendingPathComponent("docker")
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        let commonPaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        return commonPaths
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
