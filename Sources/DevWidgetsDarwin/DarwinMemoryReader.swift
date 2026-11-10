#if os(macOS)
import Darwin
import DevWidgetsCore
import Foundation

/// RAM, swap and pressure from Mach VM statistics and sysctl.
enum DarwinMemoryReader {
    static let PRESSURE_SYSCTL =
        "kern.memorystatus_vm_pressure_level"
    static let WARNING_PRESSURE: Int32 = 2
    static let CRITICAL_PRESSURE: Int32 = 4

    static func readUsage() throws -> MemoryUsage {
        let total_Bytes = ProcessInfo.processInfo.physicalMemory
        let physical = Capacity(
            used_Bytes: try readUsedBytes(),
            total_Bytes: total_Bytes
        )
        return MemoryUsage(
            physical: physical,
            swap: readSwap(),
            pressure: readPressure()
        )
    }

    /// Activity Monitor's "Memory Used": app memory (internal pages
    /// minus purgeable ones) plus wired plus compressed pages.
    static func readUsedBytes() throws -> UInt64 {
        let vm_Stats = try readVMStatistics()
        let internal_Pages = UInt64(vm_Stats.internal_page_count)
        let purgeable_Pages = UInt64(vm_Stats.purgeable_count)
        let app_Pages =
            internal_Pages
            - min(purgeable_Pages, internal_Pages)
        let used_Pages =
            app_Pages + UInt64(vm_Stats.wire_count)
            + UInt64(vm_Stats.compressor_page_count)
        return used_Pages * UInt64(getpagesize())
    }

    static func readVMStatistics() throws -> vm_statistics64 {
        var vm_Stats = vm_statistics64()
        guard requestVMStatistics(&vm_Stats) == KERN_SUCCESS else {
            throw DarwinReadError.unavailable(
                call: "host_statistics64"
            )
        }
        return vm_Stats
    }

    /// host_statistics64 expects the struct as an integer_t buffer.
    static func requestVMStatistics(
        _ vm_Stats: inout vm_statistics64
    ) -> kern_return_t {
        var stats_Count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride
                / MemoryLayout<integer_t>.stride
        )
        let integer_Count = Int(stats_Count)
        return withUnsafeMutablePointer(to: &vm_Stats) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: integer_Count
            ) { integer_Pointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    integer_Pointer,
                    &stats_Count
                )
            }
        }
    }

    static func readSwap() -> Capacity {
        let swap_Usage = readSysctl(
            "vm.swapusage",
            default: xsw_usage()
        )
        return Capacity(
            used_Bytes: swap_Usage.xsu_used,
            total_Bytes: swap_Usage.xsu_total
        )
    }

    static func readPressure() -> LoadLevel {
        let kernel_Level = readSysctl(
            PRESSURE_SYSCTL,
            default: Int32(1)
        )
        switch kernel_Level {
        case CRITICAL_PRESSURE: return .critical
        case WARNING_PRESSURE: return .elevated
        default: return .normal
        }
    }
}

/// Reads a fixed-size sysctl value, or returns the fallback. Only
/// plain values (`BitwiseCopyable`) can be filled byte by byte, and
/// a short answer keeps the fallback.
func readSysctl<Value: BitwiseCopyable>(
    _ sysctl_Name: String,
    default fallback_Value: Value
) -> Value {
    var sysctl_Value = fallback_Value
    var value_Size = MemoryLayout<Value>.size
    let call_Result = withUnsafeMutableBytes(of: &sysctl_Value) {
        sysctlbyname(sysctl_Name, $0.baseAddress, &value_Size, nil, 0)
    }
    let is_Complete =
        call_Result == 0 && value_Size == MemoryLayout<Value>.size
    return is_Complete ? sysctl_Value : fallback_Value
}
#endif
