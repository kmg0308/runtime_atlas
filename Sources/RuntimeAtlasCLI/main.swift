import Foundation
import RuntimeAtlasCore

private enum CLIExit {
    static let success: Int32 = 0
    static let failure: Int32 = 1
    static let usage: Int32 = 64
}

private struct RuntimeAtlasCLI {
    func run(arguments: [String]) -> Int32 {
        guard let command = arguments.first else {
            writeError(usageText)
            return CLIExit.usage
        }

        switch command {
        case "status":
            return status(arguments: Array(arguments.dropFirst()))
        case "actions":
            return actions(arguments: Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            writeOutput(usageText)
            return CLIExit.success
        default:
            writeError("Unknown command: \(command)\n\n\(usageText)")
            return CLIExit.usage
        }
    }

    private func status(arguments: [String]) -> Int32 {
        guard arguments == ["--json"] else {
            writeError("Usage: runtime-atlas status --json\n")
            return CLIExit.usage
        }

        do {
            var data = try StatusJSONEncoder.encode(StatusService().makeStatus())
            data.append(0x0A)
            FileHandle.standardOutput.write(data)
            return CLIExit.success
        } catch {
            writeError("Runtime Atlas status could not be read.\n")
            return CLIExit.failure
        }
    }

    private func actions(arguments: [String]) -> Int32 {
        guard arguments == ["--json"] else {
            writeError("Usage: runtime-atlas actions --json\n")
            return CLIExit.usage
        }

        do {
            let document = ActionCatalog(
                schemaVersion: 1,
                actions: try ConfigurationStore().load().value.customActions
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(document)
            data.append(0x0A)
            FileHandle.standardOutput.write(data)
            return CLIExit.success
        } catch {
            writeError("Runtime Atlas actions could not be read.\n")
            return CLIExit.failure
        }
    }

    private func writeOutput(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    private var usageText: String {
        """
        Runtime Atlas reads local worktree and runtime state.

        Usage:
          runtime-atlas status --json
          runtime-atlas actions --json
        """ + "\n"
    }
}

private struct ActionCatalog: Encodable {
    let schemaVersion: Int
    let actions: [CustomActionDefinition]
}

exit(RuntimeAtlasCLI().run(arguments: Array(CommandLine.arguments.dropFirst())))
