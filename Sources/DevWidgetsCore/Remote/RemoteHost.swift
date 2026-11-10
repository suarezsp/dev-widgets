import Foundation

/// A server the user monitors, named by its alias in
/// `~/.ssh/config` (or `user@host`). DevWidgets keeps no address,
/// key or password: the system `ssh` resolves everything.
public struct RemoteHost: Codable, Hashable, Sendable {
    public static let DEFAULT_DISK_PATH = "/"
    static let MAX_DISK_PATH_LENGTH = 255
    /// The disk path goes inside the remote script, so only plain
    /// path characters pass: no quotes, spaces, "$" or ";".
    static let DISK_PATH_CHARACTERS = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyz"
            + "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-+@"
    )

    public let alias: String
    /// The file system whose space the row shows: "/" or a mount
    /// point such as "/var/lib/docker".
    public let disk_Path: String

    /// nil for an alias `ssh` would read as an option
    /// ("-oProxy...") or that holds spaces, and for a disk path
    /// that is not a plain absolute path.
    public init?(
        alias: String,
        disk_Path: String = DEFAULT_DISK_PATH
    ) {
        let trimmed_Alias = alias.trimmingCharacters(in: .whitespaces)
        guard !trimmed_Alias.isEmpty,
            !trimmed_Alias.hasPrefix("-"),
            !trimmed_Alias.contains(where: \.isWhitespace),
            Self.isUsableDiskPath(disk_Path)
        else { return nil }
        self.alias = trimmed_Alias
        self.disk_Path = disk_Path
    }

    public static func isUsableDiskPath(_ path: String) -> Bool {
        path.hasPrefix("/") && path.count <= MAX_DISK_PATH_LENGTH
            && path.unicodeScalars.allSatisfy(
                DISK_PATH_CHARACTERS.contains
            )
    }

    /// Decoding checks too: a damaged settings file must not turn
    /// into an `ssh` option or a shell command. Hosts saved before
    /// the disk could be chosen read "/".
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let alias = try container.decode(String.self, forKey: .alias)
        let disk_Path =
            try container.decodeIfPresent(
                String.self,
                forKey: .disk_Path
            ) ?? Self.DEFAULT_DISK_PATH
        guard
            let host = RemoteHost(alias: alias, disk_Path: disk_Path)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .alias,
                in: container,
                debugDescription: "Not a usable ssh alias or disk"
            )
        }
        self = host
    }

    enum CodingKeys: String, CodingKey {
        case alias
        case disk_Path
    }
}

/// 1, 5 and 15 minute run-queue averages from `/proc/loadavg`.
public struct LoadAverage: Codable, Equatable, Sendable {
    public let one_Minute: Double
    public let five_Minutes: Double
    public let fifteen_Minutes: Double

    public init(
        one_Minute: Double,
        five_Minutes: Double,
        fifteen_Minutes: Double
    ) {
        self.one_Minute = one_Minute
        self.five_Minutes = five_Minutes
        self.fifteen_Minutes = fifteen_Minutes
    }
}

/// Counters of one poll of a remote Linux host: what one `ssh`
/// round trip brings back.
public struct RemoteSnapshot: Codable, Equatable, Sendable {
    public let cpu: CPUSample
    public let memory: MemoryUsage
    public let disk_Space: Capacity
    public var network = NetworkCounters.ZERO
    public var load_Average: LoadAverage?
    public var uptime_Seconds: Double?
    /// "Linux web-1 6.8.0-45-generic".
    public var system_Text = ""
    public var captured_At = Date()

    public init(
        cpu: CPUSample,
        memory: MemoryUsage,
        disk_Space: Capacity
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk_Space = disk_Space
    }
}

/// Why a host shows no numbers.
public enum RemoteProblem: Error, Codable, Equatable, Sendable {
    case ssh_Missing
    /// Unknown or changed host key: BatchMode never asks, so the
    /// user must connect once in Terminal and check the key.
    case host_Key_Rejected
    /// No key the server accepts, or the key needs a passphrase
    /// that is not in the agent.
    case authentication_Failed
    case unreachable(reason: String)
    /// `/proc` missing: "Darwin", "FreeBSD"...
    case not_Linux(system: String)
}

/// What the servers widget shows for one host.
public struct RemoteHostStatus: Codable, Equatable, Sendable {
    public let snapshot: RemoteSnapshot
    /// nil on the first poll: CPU needs two.
    public var cpu_Fraction: Double?
    public var network: NetworkThroughput?

    public init(snapshot: RemoteSnapshot) {
        self.snapshot = snapshot
    }

    public var core_Count: Int { snapshot.cpu.cores.count }
}

public enum RemoteHostState: Codable, Equatable, Sendable {
    case not_Loaded
    case failed(problem: RemoteProblem)
    case available(status: RemoteHostStatus)
}

public struct RemoteHostReport: Codable, Equatable, Sendable {
    public let host: RemoteHost
    public let state: RemoteHostState

    public init(host: RemoteHost, state: RemoteHostState) {
        self.host = host
        self.state = state
    }
}

/// Every monitored host, in the user's order, for the panel and
/// the servers widget.
public struct ServerOverview: Codable, Equatable, Sendable {
    public static let FILE_NAME = "servers.json"

    public let reports: [RemoteHostReport]
    public var captured_At = Date()

    public init(reports: [RemoteHostReport]) {
        self.reports = reports
    }
}

public typealias ServerStore = JSONFileStore<ServerOverview>

extension JSONFileStore where Value == ServerOverview {
    public init(directory: URL) {
        self.init(directory: directory, file_Name: Value.FILE_NAME)
    }
}
