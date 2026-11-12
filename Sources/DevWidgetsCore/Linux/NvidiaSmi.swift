import Foundation

/// GPU load on NVIDIA cards, whose driver has no busy file in
/// `/sys`: `nvidia-smi` reports it without a library binding.
enum NvidiaSmi {
    static let PCI_VENDOR_ID = "0x10de"
    static let TIMEOUT_SECONDS = 2.0
    static let ARGUMENTS = [
        "--query-gpu=utilization.gpu",
        "--format=csv,noheader,nounits",
    ]
    static let FALLBACK_PATH = "/usr/bin/nvidia-smi"

    static func makeCommand() -> Command {
        let executable_URL =
            ExecutableSearch.locate("nvidia-smi")
            ?? URL(fileURLWithPath: FALLBACK_PATH)
        var command = Command(
            executable_URL: executable_URL,
            arguments: ARGUMENTS
        )
        command.timeout_Seconds = TIMEOUT_SECONDS
        return command
    }

    /// Nil when the program is missing, fails or reports nothing.
    static func readFraction(
        using command_Runner: CommandRunner
    ) -> Double? {
        let output = try? command_Runner.run(makeCommand())
        return output.flatMap(parseFraction)
    }

    /// "12\n85\n" -> 0.85: one percentage per GPU, the busiest
    /// counts. "[N/A]" lines are skipped.
    static func parseFraction(_ text: String) -> Double? {
        text.split(whereSeparator: \.isNewline)
            .compactMap { SysfsParser.parsePercent(String($0)) }
            .max()
    }
}
