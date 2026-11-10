import Foundation
import Testing
@testable import DevWidgetsCore

struct CommandRunnerTests {
    static let SHELL_URL = URL(fileURLWithPath: "/bin/sh")

    @Test func outputIsReturned() throws {
        let output = try ProcessCommandRunner().run(
            Command(
                executable_URL: Self.SHELL_URL,
                arguments: ["-c", "echo hi"]
            )
        )
        #expect(output == "hi\n")
    }

    @Test func failureCarriesStatusAndErrorText() {
        let command = Command(
            executable_URL: Self.SHELL_URL,
            arguments: ["-c", "echo broken >&2; exit 3"]
        )
        #expect(
            throws: CommandError.failed(
                exit_Status: 3,
                error_Text: "broken\n"
            )
        ) { try ProcessCommandRunner().run(command) }
    }

    @Test func hungCommandIsStopped() {
        let command = Command(
            executable_URL: Self.SHELL_URL,
            arguments: ["-c", "sleep 5"]
        )
        let runner = ProcessCommandRunner(timeout_Seconds: 0.2)
        #expect(throws: CommandError.timed_Out(seconds: 0.2)) {
            try runner.run(command)
        }
    }

    /// The test runner blocks SIGTERM in its children, so this
    /// also proves the SIGKILL fallback: no `sleep` may survive.
    @Test func timedOutProgramDoesNotSurvive() throws {
        let command = Command(
            executable_URL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["7.25"]
        )
        let runner = ProcessCommandRunner(timeout_Seconds: 0.2)
        #expect(throws: CommandError.timed_Out(seconds: 0.2)) {
            try runner.run(command)
        }
        #expect(!Self.isRunning(arguments: "sleep\u{0}7.25"))
    }

    static func isRunning(arguments: String) -> Bool {
        let proc_URL = URL(fileURLWithPath: "/proc")
        return KernelFiles.listProcessDirectories(in: proc_URL)
            .contains {
                let cmdline_Text = KernelFiles.readText(
                    named: "cmdline",
                    in: $0
                )
                return cmdline_Text?.hasPrefix(arguments) == true
            }
    }

    /// Larger than a pipe buffer (64 KiB): must not block.
    @Test func largeOutputDoesNotBlock() throws {
        let command = Command(
            executable_URL: Self.SHELL_URL,
            arguments: [
                "-c", "head -c 300000 /dev/zero | tr '\\0' x",
            ]
        )
        let output = try ProcessCommandRunner().run(command)
        #expect(output.count == 300_000)
    }

    @Test func missingProgramIsNotFound() {
        #expect(ExecutableSearch.locate("no-such-tool-xyz") == nil)
        #expect(ExecutableSearch.locate("sh") != nil)
    }
}
