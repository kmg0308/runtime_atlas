import Darwin
import Foundation
import RuntimeAtlasCore

private enum CLIExit {
    static let success: Int32 = 0
    static let failure: Int32 = 1
    static let contextError: Int32 = 2
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
        case "verify":
            return verify(arguments: Array(arguments.dropFirst()))
        case "record":
            return record(arguments: Array(arguments.dropFirst()))
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
            let status = try StatusService().makeStatus()
            var data = try StatusJSONEncoder.encode(status)
            data.append(0x0A)
            FileHandle.standardOutput.write(data)
            return CLIExit.success
        } catch {
            writeError("Runtime Atlas status could not be read.\n")
            return CLIExit.failure
        }
    }

    private func verify(arguments: [String]) -> Int32 {
        guard arguments.first == "--" else {
            writeError("Usage: runtime-atlas verify -- <command and args>\n")
            return CLIExit.usage
        }
        let command = Array(arguments.dropFirst())
        guard !command.isEmpty else {
            writeError("A command is required after --.\n")
            return CLIExit.usage
        }

        do {
            let result = try VerificationRunner().run(
                command: command,
                currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            )
            if let saveError = result.evidenceSaveError {
                writeError("runtime-atlas: \(saveError)\n")
            }
            return result.exitCode
        } catch let error as LocalizedError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Verification could not start.")\n")
            return CLIExit.contextError
        } catch {
            writeError("runtime-atlas: Verification could not start.\n")
            return CLIExit.contextError
        }
    }

    private func record(arguments: [String]) -> Int32 {
        let options: RecordOptions
        do {
            options = try parseRecordOptions(arguments)
        } catch let error as LocalizedError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Invalid record arguments.")\n")
            writeError(recordUsage)
            return CLIExit.usage
        } catch {
            writeError("runtime-atlas: Invalid record arguments.\n")
            writeError(recordUsage)
            return CLIExit.usage
        }

        do {
            let evidence = try ManualEvidenceRecorder().record(
                kind: options.kind,
                status: options.status,
                note: options.note,
                viewport: options.viewport,
                currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            )
            writeOutput(
                "Recorded \(evidence.status.rawValue) \(evidence.kind.rawValue) evidence for \(evidence.sha.prefix(7)).\n"
            )
            return CLIExit.success
        } catch let error as EvidenceRecordingError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Evidence could not be recorded.")\n")
            writeError(recordUsage)
            return CLIExit.usage
        } catch let error as CurrentWorktreeError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Evidence context could not be resolved.")\n")
            return CLIExit.contextError
        } catch let error as CommandExecutionError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Evidence context could not be resolved.")\n")
            return CLIExit.contextError
        } catch let error as LocalizedError {
            writeError("runtime-atlas: \(error.errorDescription ?? "Evidence could not be recorded.")\n")
            return CLIExit.failure
        } catch {
            writeError("runtime-atlas: Evidence could not be recorded.\n")
            return CLIExit.failure
        }
    }

    private func parseRecordOptions(_ arguments: [String]) throws -> RecordOptions {
        var kind: EvidenceKind?
        var status: EvidenceStatus?
        var note: String?
        var viewport: String?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            guard ["--kind", "--status", "--note", "--viewport"].contains(option),
                  index + 1 < arguments.count else {
                throw CLIUsageError.invalidRecordArguments
            }
            let value = arguments[index + 1]
            switch option {
            case "--kind":
                kind = EvidenceKind(rawValue: value.lowercased())
            case "--status":
                status = EvidenceStatus(rawValue: value.uppercased())
            case "--note":
                note = value
            case "--viewport":
                viewport = value
            default:
                break
            }
            index += 2
        }

        guard let kind, kind == .browser || kind == .manual,
              let status,
              let note,
              !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIUsageError.invalidRecordArguments
        }
        return RecordOptions(kind: kind, status: status, note: note, viewport: viewport)
    }

    private func writeOutput(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    private var recordUsage: String {
        "Usage: runtime-atlas record --kind browser|manual --status PASS|FAIL|BLOCKED|PENDING --note <text> [--viewport <text>]\n"
    }

    private var usageText: String {
        """
        Runtime Atlas reads local worktree/runtime state and records SHA-bound evidence.

        Usage:
          runtime-atlas status --json
          runtime-atlas verify -- <command and args>
          \(recordUsage.trimmingCharacters(in: .newlines))

        Command output is passed through but never stored. Avoid putting secrets in arguments or notes;
        common credential-shaped values and URLs are redacted from evidence.
        """ + "\n"
    }
}

private struct RecordOptions {
    let kind: EvidenceKind
    let status: EvidenceStatus
    let note: String
    let viewport: String?
}

private enum CLIUsageError: LocalizedError {
    case invalidRecordArguments

    var errorDescription: String? {
        "Invalid record arguments."
    }
}

exit(RuntimeAtlasCLI().run(arguments: Array(CommandLine.arguments.dropFirst())))
