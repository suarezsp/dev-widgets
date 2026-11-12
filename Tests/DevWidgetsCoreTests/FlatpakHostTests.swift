import Foundation
import Testing

@testable import DevWidgetsCore

struct FlatpakHostTests {
    @Test func hostProgramRunsThroughFlatpakSpawn() {
        var command = Command(
            executable_URL: URL(
                fileURLWithPath: "/run/host/usr/bin/git"
            ),
            arguments: ["status"]
        )
        command.working_Directory = URL(
            fileURLWithPath: "/home/a/app"
        )
        command.timeout_Seconds = 3
        let routed_Command = FlatpakHost.route(command)
        #expect(
            routed_Command.executable_URL.path
                == "/usr/bin/flatpak-spawn"
        )
        #expect(
            routed_Command.arguments == [
                "--host", "--directory=/home/a/app", "/usr/bin/git",
                "status",
            ]
        )
        #expect(routed_Command.working_Directory == nil)
        #expect(routed_Command.timeout_Seconds == 3)
    }

    @Test func sandboxProgramIsLeftAlone() {
        let command = Command(
            executable_URL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: ["-V"]
        )
        #expect(FlatpakHost.route(command) == command)
    }

    @Test func hostDirectoriesOnlyInsideTheSandbox() {
        let directories = ["/usr/bin"]
        #expect(
            FlatpakHost.listHostDirectories(
                for: directories,
                is_Sandboxed: true
            ) == ["/run/host/usr/bin"]
        )
        #expect(
            FlatpakHost.listHostDirectories(
                for: directories,
                is_Sandboxed: false
            ).isEmpty
        )
    }
}
