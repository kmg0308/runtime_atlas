import Darwin
import Foundation

private nonisolated(unsafe) var supervisedChildPID: pid_t = 0

private func forwardSignal(_ signalNumber: Int32) {
    let childPID = supervisedChildPID
    guard childPID > 0 else { return }
    _ = Darwin.kill(-childPID, signalNumber)
    _ = Darwin.kill(childPID, signalNumber)
    if signalNumber == SIGTERM || signalNumber == SIGINT { alarm(2) }
}

private func forceStopChild(_ signalNumber: Int32) {
    let childPID = supervisedChildPID
    guard childPID > 0 else { return }
    _ = Darwin.kill(-childPID, SIGKILL)
    _ = Darwin.kill(childPID, SIGKILL)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let cwdIndex = arguments.firstIndex(of: "--cwd")
guard let cwdIndex,
      arguments.indices.contains(cwdIndex + 2),
      arguments[cwdIndex + 2] == "--" else {
    fputs("usage: runtime-atlas-supervisor [--session-id <uuid>] --cwd <path> -- <command> [args...]\n", stderr)
    exit(64)
}

guard setpgid(0, 0) == 0 || errno == EACCES || (errno == EPERM && getpgrp() == getpid()) else {
    perror("setpgid")
    exit(71)
}

let command = Array(arguments.dropFirst(cwdIndex + 3))
guard !command.isEmpty else { exit(64) }

let child = Process()
child.executableURL = URL(fileURLWithPath: "/bin/zsh")
child.arguments = [
    "-lc",
    "if [[ -r \"${ZDOTDIR:-$HOME}/.zshrc\" ]]; then source \"${ZDOTDIR:-$HOME}/.zshrc\"; fi; exec \"$@\"",
    "runtime-atlas"
] + command
child.currentDirectoryURL = URL(fileURLWithPath: arguments[cwdIndex + 1], isDirectory: true)

do {
    signal(SIGTERM, forwardSignal)
    signal(SIGINT, forwardSignal)
    signal(SIGALRM, forceStopChild)
    try child.run()
    supervisedChildPID = child.processIdentifier
    child.waitUntilExit()
    supervisedChildPID = 0
    alarm(0)
    exit(child.terminationStatus)
} catch {
    fputs("runtime-atlas-supervisor: \(error.localizedDescription)\n", stderr)
    exit(71)
}
