import Foundation

public enum UpdateArchiveValidationError: Error, CustomStringConvertible {
    case missingArchive
    case invalidArchive(String)
    case invalidAppBundle(String)
    case invalidCodeSignature(String)

    public var description: String {
        switch self {
        case .missingArchive:
            return "Downloaded update archive is missing."
        case .invalidArchive(let detail):
            return "Downloaded update archive is invalid: \(detail)"
        case .invalidAppBundle(let detail):
            return "Downloaded app bundle is invalid: \(detail)"
        case .invalidCodeSignature(let detail):
            return "Downloaded app code signature is invalid: \(detail)"
        }
    }
}

public enum UpdateArchiveValidator {
    public static func validate(_ zipURL: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: zipURL.path) else {
            throw UpdateArchiveValidationError.missingArchive
        }

        let workURL = fileManager.temporaryDirectory
            .appendingPathComponent("runtime-atlas-update-preflight-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workURL) }

        do {
            try runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", zipURL.path, workURL.path]
            )
        } catch {
            throw UpdateArchiveValidationError.invalidArchive(String(describing: error))
        }

        let appURL = workURL.appendingPathComponent(
            UpdateReleasePolicy.runtimeAtlasArchiveName,
            isDirectory: true
        )
        do {
            try UpdateReleasePolicy.validateRuntimeAtlasAppBundle(at: appURL, fileManager: fileManager)
        } catch {
            throw UpdateArchiveValidationError.invalidAppBundle(String(describing: error))
        }

        do {
            try runProcess(
                executable: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", appURL.path]
            )
            try runProcess(
                executable: "/usr/bin/codesign",
                arguments: [
                    "--verify", "--strict",
                    appURL
                        .appendingPathComponent("Contents", isDirectory: true)
                        .appendingPathComponent("Helpers", isDirectory: true)
                        .appendingPathComponent(UpdateReleasePolicy.runtimeAtlasCLIHelperName)
                        .path
                ]
            )
        } catch {
            throw UpdateArchiveValidationError.invalidCodeSignature(String(describing: error))
        }
    }

    private static func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw UpdateArchiveProcessFailure(
                message: message ?? "exit \(process.terminationStatus)"
            )
        }
    }
}

private struct UpdateArchiveProcessFailure: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}
