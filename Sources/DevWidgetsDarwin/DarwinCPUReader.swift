#if os(macOS)
import Darwin
import DevWidgetsCore

/// Per-core tick counters from `host_processor_info`.
enum DarwinCPUReader {
    static func readSample() throws -> CPUSample {
        let core_Ticks = try readCoreTicks()
        let total_Ticks = core_Ticks.reduce(.ZERO, +)
        return CPUSample(total: total_Ticks, cores: core_Ticks)
    }

    static func readCoreTicks() throws -> [CPUTicks] {
        var core_Count: natural_t = 0
        var info_Array: processor_info_array_t?
        var info_Count: mach_msg_type_number_t = 0
        let call_Result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &core_Count,
            &info_Array,
            &info_Count
        )
        guard call_Result == KERN_SUCCESS, let info_Array else {
            throw DarwinReadError.unavailable(
                call: "host_processor_info"
            )
        }
        defer { releaseInfoArray(info_Array, count: info_Count) }
        return (0..<Int(core_Count)).map { core_Index in
            coreTicks(in: info_Array, core_Index: core_Index)
        }
    }

    /// Mach exposes 32-bit counters; a wrap reads as one idle sample.
    static func coreTicks(
        in info_Array: processor_info_array_t,
        core_Index: Int
    ) -> CPUTicks {
        let base_Index = core_Index * Int(CPU_STATE_MAX)
        func ticks(_ cpu_State: Int32) -> UInt64 {
            let raw_Value = info_Array[
                base_Index + Int(cpu_State)
            ]
            return UInt64(UInt32(bitPattern: raw_Value))
        }
        let busy_Ticks =
            ticks(CPU_STATE_USER)
            + ticks(CPU_STATE_SYSTEM) + ticks(CPU_STATE_NICE)
        return CPUTicks(
            busy_Ticks: busy_Ticks,
            idle_Ticks: ticks(CPU_STATE_IDLE)
        )
    }

    static func releaseInfoArray(
        _ info_Array: processor_info_array_t,
        count info_Count: mach_msg_type_number_t
    ) {
        let byte_Count =
            Int(info_Count)
            * MemoryLayout<integer_t>.stride
        vm_deallocate(
            mach_task_self_,
            vm_address_t(bitPattern: info_Array),
            vm_size_t(byte_Count)
        )
    }
}
#endif
