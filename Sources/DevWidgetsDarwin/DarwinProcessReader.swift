#if os(macOS)
import Darwin
import DevWidgetsCore

/// Per-process CPU time and memory through libproc. Without root,
/// only the user's own processes answer; that is the useful set.
enum DarwinProcessReader {
    static let NANOSECONDS_PER_SECOND = 1_000_000_000.0
    /// `proc_name` writes up to 2 * MAXCOMLEN characters.
    static let NAME_BUFFER_SIZE = 2 * Int(MAXCOMLEN) + 1
    /// Room for processes started between the two listing calls.
    static let EXTRA_PROCESS_SLOTS = 64

    static func readProcesses() -> [ProcessCounters] {
        let nanoseconds_Per_Tick = readNanosecondsPerTick()
        return listProcessIDs().compactMap {
            readCounters(
                of: $0,
                nanoseconds_Per_Tick: nanoseconds_Per_Tick
            )
        }
    }

    static func listProcessIDs() -> [pid_t] {
        let process_Count = proc_listallpids(nil, 0)
        guard process_Count > 0 else { return [] }
        var process_IDs = [pid_t](
            repeating: 0,
            count: Int(process_Count) + EXTRA_PROCESS_SLOTS
        )
        let listed_Count = process_IDs.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard listed_Count > 0 else { return [] }
        return process_IDs.prefix(Int(listed_Count)).filter { $0 > 0 }
    }

    /// Task times are Mach ticks, not nanoseconds, on Apple silicon.
    static func readCounters(
        of process_ID: pid_t,
        nanoseconds_Per_Tick: Double
    ) -> ProcessCounters? {
        guard let task_Info = readTaskInfo(of: process_ID) else {
            return nil
        }
        return ProcessCounters(
            identity: ProcessIdentity(
                pid: process_ID,
                name: readName(of: process_ID)
            ),
            cpu_Seconds: cpuSeconds(
                of: task_Info,
                nanoseconds_Per_Tick: nanoseconds_Per_Tick
            ),
            resident_Bytes: task_Info.pti_resident_size
        )
    }

    /// Fails for processes of other users and ones that just quit.
    static func readTaskInfo(of process_ID: pid_t) -> proc_taskinfo? {
        var task_Info = proc_taskinfo()
        let info_Size = Int32(MemoryLayout<proc_taskinfo>.size)
        let read_Size = proc_pidinfo(
            process_ID,
            PROC_PIDTASKINFO,
            0,
            &task_Info,
            info_Size
        )
        return read_Size == info_Size ? task_Info : nil
    }

    static func cpuSeconds(
        of task_Info: proc_taskinfo,
        nanoseconds_Per_Tick: Double
    ) -> Double {
        let cpu_Ticks = Double(
            task_Info.pti_total_user + task_Info.pti_total_system
        )
        return cpu_Ticks * nanoseconds_Per_Tick
            / NANOSECONDS_PER_SECOND
    }

    static func readName(of process_ID: pid_t) -> String {
        var name_Buffer = [CChar](
            repeating: 0,
            count: NAME_BUFFER_SIZE
        )
        _ = proc_name(
            process_ID,
            &name_Buffer,
            UInt32(NAME_BUFFER_SIZE)
        )
        return stringFromCBuffer(name_Buffer)
    }

    static func readNanosecondsPerTick() -> Double {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS,
            timebase.denom > 0
        else { return 1 }
        return Double(timebase.numer) / Double(timebase.denom)
    }
}
/// Current name of a pid, for checking that a process asked to
/// quit is still the program the user saw.
public enum DarwinProcessNames {
    /// nil when the process is gone.
    public static func readName(of process_ID: Int32) -> String? {
        let name = DarwinProcessReader.readName(of: process_ID)
        return name.isEmpty ? nil : name
    }
}
#endif
