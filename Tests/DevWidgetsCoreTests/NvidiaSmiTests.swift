import Foundation
import Testing

@testable import DevWidgetsCore

struct NvidiaSmiTests {
    static let NVIDIA_SYS_DIRECTORY =
        Fixtures.ROOT_DIRECTORY
        .appendingPathComponent("sys-nvidia")

    static func makeRunner() throws -> FakeCommandRunner {
        let output = try Fixtures.rootText(
            "nvidia/utilization-two-gpus.txt"
        )
        return FakeCommandRunner(
            outputs: [NvidiaSmi.ARGUMENTS[0]: output]
        )
    }

    @Test func busiestGPUCounts() throws {
        let output = try Fixtures.rootText(
            "nvidia/utilization-two-gpus.txt"
        )
        #expect(NvidiaSmi.parseFraction(output) == 0.85)
        #expect(NvidiaSmi.parseFraction("[N/A]\n") == nil)
        #expect(NvidiaSmi.parseFraction("") == nil)
    }

    @Test func nvidiaCardIsReadWithNvidiaSmi() throws {
        let command_Runner = try Self.makeRunner()
        let hardware_Reader = LinuxHardwareReader(
            sys_Directory: Self.NVIDIA_SYS_DIRECTORY,
            command_Runner: command_Runner
        )
        #expect(hardware_Reader.readGPUFraction() == 0.85)
        let command = try #require(command_Runner.run_Commands.first)
        #expect(command.arguments == NvidiaSmi.ARGUMENTS)
        #expect(command.timeout_Seconds == NvidiaSmi.TIMEOUT_SECONDS)
    }

    @Test func busyFileWinsWithoutRunningNvidiaSmi() throws {
        let command_Runner = try Self.makeRunner()
        let hardware_Reader = LinuxHardwareReader(
            sys_Directory: Fixtures.SYS_DIRECTORY,
            command_Runner: command_Runner
        )
        #expect(hardware_Reader.readGPUFraction() == 0.37)
        #expect(command_Runner.run_Commands.isEmpty)
    }

    @Test func failingNvidiaSmiMeansUnknownLoad() {
        let hardware_Reader = LinuxHardwareReader(
            sys_Directory: Self.NVIDIA_SYS_DIRECTORY,
            command_Runner: FailingCommandRunner(error_Text: "absent")
        )
        #expect(hardware_Reader.readGPUFraction() == nil)
    }
}
