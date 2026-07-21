import Foundation

public struct ParsedListeningProcess: Equatable, Sendable {
    public var pid: Int32
    public var name: String
    public var ports: [ListeningPort]

    public init(pid: Int32, name: String, ports: [ListeningPort]) {
        self.pid = pid
        self.name = name
        self.ports = ports
    }
}

public enum LsofParser {
    public static func parseListeningProcesses(_ output: String) -> [ParsedListeningProcess] {
        var records: [Int32: ParsedListeningProcess] = [:]
        var currentPID: Int32?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value)
                if let pid = currentPID, records[pid] == nil {
                    records[pid] = ParsedListeningProcess(pid: pid, name: "Unknown", ports: [])
                }
            case "c":
                if let pid = currentPID {
                    records[pid]?.name = value
                }
            case "n":
                if let pid = currentPID, let port = parsePort(value) {
                    if !records[pid, default: ParsedListeningProcess(pid: pid, name: "Unknown", ports: [])]
                        .ports.contains(port) {
                        records[pid]?.ports.append(port)
                    }
                }
            default:
                continue
            }
        }

        return records.values
            .map { record in
                var copy = record
                copy.ports.sort { lhs, rhs in
                    lhs.port == rhs.port ? lhs.address < rhs.address : lhs.port < rhs.port
                }
                return copy
            }
            .sorted { $0.pid < $1.pid }
    }

    public static func parseWorkingDirectories(_ output: String) -> [Int32: String] {
        var result: [Int32: String] = [:]
        var currentPID: Int32?
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let prefix = line.first else { continue }
            let value = String(line.dropFirst())
            if prefix == "p" {
                currentPID = Int32(value)
            } else if prefix == "n", let pid = currentPID, value.hasPrefix("/") {
                result[pid] = PathUtilities.canonical(value)
            }
        }
        return result
    }

    private static func parsePort(_ rawName: String) -> ListeningPort? {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("TCP ") {
            name.removeFirst(4)
        }
        if let listenRange = name.range(of: " (LISTEN)", options: .backwards) {
            name.removeSubrange(listenRange)
        }
        guard let colon = name.lastIndex(of: ":"),
              let port = Int(name[name.index(after: colon)...]),
              (1...65_535).contains(port) else {
            return nil
        }
        let address = String(name[..<colon])
        return ListeningPort(address: address.isEmpty ? "*" : address, port: port)
    }
}

public struct ProcessDiscoveryResult: Equatable, Sendable {
    public let availability: DiscoveryAvailability
    public let processes: [RuntimeProcess]

    public init(availability: DiscoveryAvailability, processes: [RuntimeProcess]) {
        self.availability = availability
        self.processes = processes
    }
}

public struct ProcessDetector: Sendable {
    private let executor: CommandExecutor

    public init(executor: CommandExecutor = CommandExecutor()) {
        self.executor = executor
    }

    public func detect() -> ProcessDiscoveryResult {
        let listening: CommandResult
        do {
            listening = try executor.run(
                executable: ExecutableLocator.lsof,
                arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
            )
        } catch {
            return unavailable("Listening TCP ports could not be read.")
        }

        if listening.exitCode != 0,
           listening.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           listening.standardError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ProcessDiscoveryResult(availability: .available, processes: [])
        }
        guard listening.exitCode == 0 else {
            return unavailable("Listening TCP ports could not be read.")
        }

        let parsed = LsofParser.parseListeningProcesses(listening.standardOutput)
        guard !parsed.isEmpty else {
            return ProcessDiscoveryResult(availability: .available, processes: [])
        }

        let pidList = parsed.map { String($0.pid) }.joined(separator: ",")
        let cwdOutput: String
        do {
            let cwd = try executor.run(
                executable: ExecutableLocator.lsof,
                arguments: ["-a", "-p", pidList, "-d", "cwd", "-Fn"]
            )
            cwdOutput = cwd.standardOutput
        } catch {
            cwdOutput = ""
        }
        let directories = LsofParser.parseWorkingDirectories(cwdOutput)

        let processes = parsed.map { process in
            RuntimeProcess(
                pid: process.pid,
                name: process.name,
                cwd: directories[process.pid],
                ports: process.ports
            )
        }
        return ProcessDiscoveryResult(availability: .available, processes: processes)
    }

    private func unavailable(_ reason: String) -> ProcessDiscoveryResult {
        ProcessDiscoveryResult(
            availability: DiscoveryAvailability(state: .unavailable, reason: reason),
            processes: []
        )
    }
}

public enum DockerInspectParser {
    public static func parse(_ data: Data) -> [RuntimeContainer]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        var containers: [RuntimeContainer] = []
        for object in root {
            guard let id = object["Id"] as? String,
                  !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            let rawName = object["Name"] as? String ?? "Unnamed"
            let name = rawName.hasPrefix("/") ? String(rawName.dropFirst()) : rawName
            let config = object["Config"] as? [String: Any]
            let image = config?["Image"] as? String ?? "Unknown image"
            let mounts = (object["Mounts"] as? [[String: Any]] ?? [])
                .compactMap { $0["Source"] as? String }
                .map(PathUtilities.canonical)
                .sorted()

            var ports = Set<PublishedPort>()
            let network = object["NetworkSettings"] as? [String: Any]
            let portMap = network?["Ports"] as? [String: Any] ?? [:]
            for (containerKey, rawBindings) in portMap {
                let keyParts = containerKey.split(separator: "/", maxSplits: 1).map(String.init)
                guard let containerPort = Int(keyParts.first ?? "") else { continue }
                let transport = keyParts.count > 1 ? keyParts[1] : "tcp"
                guard let bindings = rawBindings as? [[String: Any]] else { continue }
                for binding in bindings {
                    guard let hostPortText = binding["HostPort"] as? String,
                          let hostPort = Int(hostPortText) else { continue }
                    let hostIP = binding["HostIp"] as? String ?? ""
                    ports.insert(
                        PublishedPort(
                            hostIP: hostIP,
                            hostPort: hostPort,
                            containerPort: containerPort,
                            transport: transport
                        )
                    )
                }
            }

            containers.append(
                RuntimeContainer(
                    id: id,
                    name: name,
                    image: image,
                    mountSources: mounts,
                    ports: ports.sorted {
                        if $0.hostPort != $1.hostPort { return $0.hostPort < $1.hostPort }
                        return $0.containerPort < $1.containerPort
                    }
                )
            )
        }
        return containers.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

public struct DockerDiscoveryResult: Equatable, Sendable {
    public let availability: DiscoveryAvailability
    public let containers: [RuntimeContainer]

    public init(availability: DiscoveryAvailability, containers: [RuntimeContainer]) {
        self.availability = availability
        self.containers = containers
    }
}

public struct DockerDetector: Sendable {
    private let executor: CommandExecutor
    private let executable: URL?

    public init(
        executor: CommandExecutor = CommandExecutor(),
        executable: URL? = ExecutableLocator.docker()
    ) {
        self.executor = executor
        self.executable = executable
    }

    public func detect() -> DockerDiscoveryResult {
        guard let executable else {
            return unavailable("Docker CLI is not installed.")
        }

        let info: CommandResult
        do {
            info = try executor.run(
                executable: executable,
                arguments: ["info", "--format", "{{.ServerVersion}}"]
            )
        } catch {
            return unavailable("Docker CLI could not be launched.")
        }
        guard info.exitCode == 0 else {
            return unavailable(classifyUnavailable(info.standardError + "\n" + info.standardOutput))
        }

        let listing: CommandResult
        do {
            listing = try executor.run(
                executable: executable,
                arguments: ["ps", "--quiet", "--no-trunc"]
            )
        } catch {
            return unavailable("Docker containers could not be read.")
        }
        guard listing.exitCode == 0 else {
            return unavailable(classifyUnavailable(listing.standardError + "\n" + listing.standardOutput))
        }

        let identifiers = listing.standardOutput
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard !identifiers.isEmpty else {
            return DockerDiscoveryResult(availability: .available, containers: [])
        }

        let inspection: CommandResult
        do {
            inspection = try executor.run(
                executable: executable,
                arguments: ["inspect"] + identifiers
            )
        } catch {
            return unavailable("Docker container details could not be read.")
        }
        guard inspection.exitCode == 0 else {
            return unavailable(classifyUnavailable(inspection.standardError + "\n" + inspection.standardOutput))
        }

        guard let containers = DockerInspectParser.parse(Data(inspection.standardOutput.utf8)),
              containers.count == identifiers.count else {
            return unavailable("Docker container details could not be parsed.")
        }
        return DockerDiscoveryResult(availability: .available, containers: containers)
    }

    private func classifyUnavailable(_ output: String) -> String {
        let normalized = output.lowercased()
        if normalized.contains("permission denied") || normalized.contains("not permitted") {
            return "Docker is unavailable: permission denied."
        }
        if normalized.contains("cannot connect")
            || normalized.contains("daemon")
            || normalized.contains("is the docker daemon running") {
            return "Docker daemon is not responding."
        }
        return "Docker is unavailable."
    }

    private func unavailable(_ reason: String) -> DockerDiscoveryResult {
        DockerDiscoveryResult(
            availability: DiscoveryAvailability(state: .unavailable, reason: reason),
            containers: []
        )
    }
}
