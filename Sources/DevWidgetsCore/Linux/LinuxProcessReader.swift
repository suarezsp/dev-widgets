#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// Per-process CPU time and memory from `/proc/[pid]/stat`.
public struct LinuxProcessReader {
    let proc_Directory: URL

    static func currentUnits() -> KernelUnits {
        KernelUnits(
            ticks_Per_Second: Double(sysconf(Int32(_SC_CLK_TCK))),
            page_Bytes: UInt64(sysconf(Int32(_SC_PAGESIZE)))
        )
    }

    func readProcesses() -> [ProcessCounters] {
        let units = Self.currentUnits()
        return KernelFiles.listProcessDirectories(in: proc_Directory)
            .compactMap {
                KernelFiles.readText(named: "stat", in: $0)
            }
            .compactMap {
                ProcessStatParser.parseCounters(
                    stat_Text: $0,
                    units: units
                )
            }
    }

    /// The name `readProcesses` reports for this pid, if alive.
    public static func readName(
        of process_ID: Int32,
        proc_Directory: URL = URL(fileURLWithPath: "/proc")
    ) -> String? {
        let process_Directory = proc_Directory.appendingPathComponent(
            "\(process_ID)"
        )
        return KernelFiles.readText(
            named: "stat",
            in: process_Directory
        )
        .flatMap { ProcessStatParser.splitIdentity($0)?.0.name }
    }
}
