/// Identifies a process across samples. The name guards against a
/// pid being reused by a different program between two samples.
public struct ProcessIdentity: Codable, Hashable, Sendable {
    public let pid: Int32
    public let name: String

    public init(pid: Int32, name: String) {
        self.pid = pid
        self.name = name
    }
}

/// Cumulative CPU time and current memory of one process.
public struct ProcessCounters: Equatable, Sendable {
    public let identity: ProcessIdentity
    public let cpu_Seconds: Double
    public let resident_Bytes: UInt64

    public init(
        identity: ProcessIdentity,
        cpu_Seconds: Double,
        resident_Bytes: UInt64
    ) {
        self.identity = identity
        self.cpu_Seconds = cpu_Seconds
        self.resident_Bytes = resident_Bytes
    }
}

/// CPU use of one process between two samples. Like Activity
/// Monitor, 1.0 means one full core, so values can exceed 1.
public struct ProcessUsage: Codable, Equatable, Sendable {
    public let identity: ProcessIdentity
    public let cpu_Fraction: Double
    public let resident_Bytes: UInt64
}

public enum ProcessRanking {
    public static let TOP_COUNT = 5

    /// Busiest processes first; memory breaks ties. Processes that
    /// started after the previous sample have no rate yet.
    public static func rankBusiest(
        from previous: [ProcessCounters],
        to current: [ProcessCounters],
        elapsed_Seconds: Double
    ) -> [ProcessUsage] {
        guard elapsed_Seconds > 0 else { return [] }
        let previous_Seconds = Dictionary(
            previous.map { ($0.identity, $0.cpu_Seconds) },
            uniquingKeysWith: { first_Value, _ in first_Value }
        )
        let usages = current.compactMap { counters in
            previous_Seconds[counters.identity].map { old_Seconds in
                makeUsage(
                    of: counters,
                    since: old_Seconds,
                    over: elapsed_Seconds
                )
            }
        }
        return Array(usages.sorted(by: isBusier).prefix(TOP_COUNT))
    }

    static func makeUsage(
        of counters: ProcessCounters,
        since old_Seconds: Double,
        over elapsed_Seconds: Double
    ) -> ProcessUsage {
        let busy_Seconds = max(0, counters.cpu_Seconds - old_Seconds)
        return ProcessUsage(
            identity: counters.identity,
            cpu_Fraction: busy_Seconds / elapsed_Seconds,
            resident_Bytes: counters.resident_Bytes
        )
    }

    static func isBusier(
        _ left: ProcessUsage,
        _ right: ProcessUsage
    ) -> Bool {
        if left.cpu_Fraction != right.cpu_Fraction {
            return left.cpu_Fraction > right.cpu_Fraction
        }
        return left.resident_Bytes > right.resident_Bytes
    }
}
