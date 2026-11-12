import Foundation

/// Inside the Flatpak, the host's programs are visible under
/// `/run/host` (`--filesystem=host-os:ro`) but must run on the host,
/// where Git, Docker and `gh` see the user's real files and
/// daemons: `flatpak-spawn --host` does that.
public enum FlatpakHost {
    public static let HOST_ROOT = "/run/host"
    static let SPAWN_PATH = "/usr/bin/flatpak-spawn"
    static let INFO_PATH = "/.flatpak-info"
    public static let IS_SANDBOXED = FileManager.default.fileExists(
        atPath: INFO_PATH
    )

    /// Where to look for a program after the usual directories.
    static func listHostDirectories(
        for directories: [String],
        is_Sandboxed: Bool = IS_SANDBOXED
    ) -> [String] {
        is_Sandboxed ? directories.map { HOST_ROOT + $0 } : []
    }

    /// A command for a program under `/run/host` runs it on the
    /// host instead; any other command is left as it is.
    static func route(_ command: Command) -> Command {
        let path = command.executable_URL.path
        guard path.hasPrefix(HOST_ROOT + "/") else { return command }
        let directory_Arguments = command.working_Directory.map {
            ["--directory=\($0.path)"]
        }
        var routed_Command = Command(
            executable_URL: URL(fileURLWithPath: SPAWN_PATH),
            arguments: ["--host"] + (directory_Arguments ?? [])
                + [String(path.dropFirst(HOST_ROOT.count))]
                + command.arguments
        )
        routed_Command.timeout_Seconds = command.timeout_Seconds
        return routed_Command
    }
}
