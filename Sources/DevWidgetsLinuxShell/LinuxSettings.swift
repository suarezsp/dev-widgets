import DevWidgetsCore
import Foundation

/// What the Linux app remembers between launches: the alert
/// limits, the monitored servers and the chosen project. No
/// secrets: `ssh` and `gh` keep their own credentials.
public struct LinuxSettings: Codable, Equatable, Sendable {
    public static let FILE_NAME = "settings.json"

    public var alert_Settings = AlertSettings.DEFAULT
    public var hosts: [RemoteHost] = []
    public var project_Path: String?

    public init() {}

    public var project_URL: URL? {
        project_Path.map { URL(fileURLWithPath: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case alert_Settings
        case hosts
        case project_Path
    }

    /// Any missing key takes its default, so a file written by an
    /// older version keeps what it has.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = LinuxSettings()
        alert_Settings =
            try container.decodeIfPresent(
                AlertSettings.self,
                forKey: .alert_Settings
            ) ?? defaults.alert_Settings
        hosts =
            try container.decodeIfPresent(
                [SkippingDamagedHost].self,
                forKey: .hosts
            )?.compactMap(\.host) ?? defaults.hosts
        project_Path = try container.decodeIfPresent(
            String.self,
            forKey: .project_Path
        )
    }
}

/// A host entry that fails validation (edited by hand, say) is
/// dropped alone instead of failing the whole file.
struct SkippingDamagedHost: Decodable {
    let host: RemoteHost?

    init(from decoder: Decoder) throws {
        host = try? RemoteHost(from: decoder)
    }
}

/// `settings.json` in `$XDG_CONFIG_HOME/devwidgets` (usually
/// `~/.config/devwidgets`).
public struct LinuxSettingsStore: Sendable {
    public let store: JSONFileStore<LinuxSettings>

    public init(directory: URL = LinuxSettingsStore.findDirectory()) {
        store = JSONFileStore(
            directory: directory,
            file_Name: LinuxSettings.FILE_NAME
        )
    }

    public static func findDirectory(
        environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) -> URL {
        let config_Path =
            environment["XDG_CONFIG_HOME"].flatMap {
                $0.isEmpty ? nil : $0
            }
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config").path
        return URL(fileURLWithPath: config_Path)
            .appendingPathComponent("devwidgets")
    }

    /// Defaults when the file is missing or unreadable: a damaged
    /// file must not stop the app from starting.
    public func load() -> LinuxSettings {
        (try? store.load()) ?? LinuxSettings()
    }

    public func save(_ settings: LinuxSettings) throws {
        try FileManager.default.createDirectory(
            at: store.file_URL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try store.save(settings)
    }
}
