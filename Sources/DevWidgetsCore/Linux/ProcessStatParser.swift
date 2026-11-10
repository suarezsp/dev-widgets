/// Units the kernel uses in `/proc/[pid]/stat`.
public struct KernelUnits: Sendable {
    public let ticks_Per_Second: Double
    public let page_Bytes: UInt64

    public init(ticks_Per_Second: Double, page_Bytes: UInt64) {
        self.ticks_Per_Second = ticks_Per_Second
        self.page_Bytes = page_Bytes
    }
}

/// Parses `/proc/[pid]/stat`: "pid (name) state ppid ...". The name
/// may contain spaces and parentheses, so it is cut at the last ")".
public enum ProcessStatParser {
    /// Indices after the name: utime is field 14, stime 15, rss 24.
    static let USER_TICKS_INDEX = 11
    static let SYSTEM_TICKS_INDEX = 12
    static let RESIDENT_PAGES_INDEX = 21

    public static func parseCounters(
        stat_Text: String,
        units: KernelUnits
    ) -> ProcessCounters? {
        guard let (identity, fields) = splitIdentity(stat_Text),
            fields.count > RESIDENT_PAGES_INDEX,
            let user_Ticks = Double(fields[USER_TICKS_INDEX]),
            let system_Ticks = Double(fields[SYSTEM_TICKS_INDEX]),
            let resident_Pages = UInt64(fields[RESIDENT_PAGES_INDEX])
        else { return nil }
        return ProcessCounters(
            identity: identity,
            cpu_Seconds: (user_Ticks + system_Ticks)
                / units.ticks_Per_Second,
            resident_Bytes: resident_Pages * units.page_Bytes
        )
    }

    static func splitIdentity(
        _ stat_Text: String
    ) -> (ProcessIdentity, [Substring])? {
        guard let open_Index = stat_Text.firstIndex(of: "("),
            let close_Index = stat_Text.lastIndex(of: ")"),
            open_Index < close_Index,
            let process_ID = Int32(
                SysfsParser.trimmed(String(stat_Text[..<open_Index]))
            )
        else { return nil }
        let name_Start = stat_Text.index(after: open_Index)
        let identity = ProcessIdentity(
            pid: process_ID,
            name: String(stat_Text[name_Start..<close_Index])
        )
        let fields = stat_Text[stat_Text.index(after: close_Index)...]
            .split(separator: " ")
        return (identity, fields)
    }
}
