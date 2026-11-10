/// Pure parsers for Linux `/proc` files. They never touch the file
/// system, so they are unit-tested with recorded fixtures.
public enum ProcStatParser {
    /// Parses `/proc/stat`; nil when the aggregate line is missing.
    public static func parseCPUSample(
        from text: String
    ) -> CPUSample? {
        var total_Ticks: CPUTicks?
        var core_Ticks: [CPUTicks] = []
        for line in text.split(separator: "\n")
        where line.hasPrefix("cpu") {
            let columns = line.split(separator: " ")
            guard let ticks = parseTicks(columns.dropFirst()) else {
                continue
            }
            if columns[0] == "cpu" {
                total_Ticks = ticks
            } else {
                core_Ticks.append(ticks)
            }
        }
        guard let total_Ticks else { return nil }
        return CPUSample(total: total_Ticks, cores: core_Ticks)
    }

    /// Columns: user nice system idle iowait irq softirq steal.
    /// Guest time is already part of user time, so it is skipped.
    static func parseTicks(
        _ columns: ArraySlice<Substring>
    ) -> CPUTicks? {
        let tick_Values = columns.prefix(8).compactMap { UInt64($0) }
        guard tick_Values.count >= 4 else { return nil }
        let io_Wait_Ticks = tick_Values.count > 4 ? tick_Values[4] : 0
        let idle_Ticks = tick_Values[3] + io_Wait_Ticks
        let busy_Ticks = tick_Values.reduce(0, +) - idle_Ticks
        return CPUTicks(
            busy_Ticks: busy_Ticks,
            idle_Ticks: idle_Ticks
        )
    }
}

public enum MemInfoParser {
    public static let BYTES_PER_KIBIBYTE: UInt64 = 1024

    /// Builds memory usage from `/proc/meminfo`. When the kernel has
    /// no pressure data, pressure falls back to the used share.
    public static func parseMemory(
        meminfo_Text: String,
        pressure_Level: LoadLevel?
    ) -> MemoryUsage? {
        let fields = parseFields(meminfo_Text)
        guard let total_Bytes = fields["MemTotal"],
            let available_Bytes = fields["MemAvailable"]
        else {
            return nil
        }
        let physical = capacityFromAvailable(
            available_Bytes,
            total_Bytes: total_Bytes
        )
        let swap = capacityFromAvailable(
            fields["SwapFree"] ?? 0,
            total_Bytes: fields["SwapTotal"] ?? 0
        )
        return MemoryUsage(
            physical: physical,
            swap: swap,
            pressure: pressure_Level ?? usedSharePressure(physical)
        )
    }

    static func usedSharePressure(_ physical: Capacity) -> LoadLevel {
        LoadThresholds.DEFAULT.level(for: physical.used_Fraction)
    }

    /// "MemTotal:  16314960 kB" becomes ["MemTotal": bytes].
    static func parseFields(_ text: String) -> [String: UInt64] {
        var fields: [String: UInt64] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let value = UInt64(parts[1])
            else {
                continue
            }
            let is_Kibibytes = parts.count > 2 && parts[2] == "kB"
            let field_Name = String(parts[0].dropLast())
            fields[field_Name] =
                is_Kibibytes
                ? value * BYTES_PER_KIBIBYTE
                : value
        }
        return fields
    }

    /// The kernel reports what is free; widgets show what is used.
    static func capacityFromAvailable(
        _ available_Bytes: UInt64,
        total_Bytes: UInt64
    ) -> Capacity {
        let used_Bytes =
            total_Bytes - min(available_Bytes, total_Bytes)
        return Capacity(
            used_Bytes: used_Bytes,
            total_Bytes: total_Bytes
        )
    }
}

public enum PressureStallParser {
    /// Share of the last 10 s in which some task waited for memory.
    public static let MEMORY_STALL_THRESHOLDS = LoadThresholds(
        elevated_Limit: 0.10,
        critical_Limit: 0.40
    )

    /// Grades the "some avg10=" value of `/proc/pressure/memory`.
    public static func parseLevel(from text: String) -> LoadLevel? {
        let some_Line = text.split(separator: "\n")
            .first { $0.hasPrefix("some ") }
        let average_Field = some_Line?.split(separator: " ")
            .first { $0.hasPrefix("avg10=") }
        guard let average_Field,
            let stall_Percent = Double(average_Field.dropFirst(6))
        else { return nil }
        return MEMORY_STALL_THRESHOLDS.level(for: stall_Percent / 100)
    }
}
