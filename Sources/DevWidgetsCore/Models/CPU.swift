/// Cumulative CPU time counters reported by the kernel, in ticks.
public struct CPUTicks: Codable, Equatable, Sendable {
    public let busy_Ticks: UInt64
    public let idle_Ticks: UInt64

    public init(busy_Ticks: UInt64, idle_Ticks: UInt64) {
        self.busy_Ticks = busy_Ticks
        self.idle_Ticks = idle_Ticks
    }

    public static let ZERO = CPUTicks(busy_Ticks: 0, idle_Ticks: 0)

    public var total_Ticks: UInt64 { busy_Ticks + idle_Ticks }

    /// Sums per-core counters into machine-wide counters.
    public static func + (left: CPUTicks, right: CPUTicks) -> CPUTicks
    {
        CPUTicks(
            busy_Ticks: left.busy_Ticks + right.busy_Ticks,
            idle_Ticks: left.idle_Ticks + right.idle_Ticks
        )
    }

    /// Busy share in 0...1 of the time elapsed since `previous`.
    /// Returns zero when counters went backwards (core reset).
    public func busyFraction(since previous: CPUTicks) -> Double {
        guard busy_Ticks >= previous.busy_Ticks,
            total_Ticks > previous.total_Ticks
        else { return 0 }
        let busy_Delta = busy_Ticks - previous.busy_Ticks
        let total_Delta = total_Ticks - previous.total_Ticks
        return min(1, Double(busy_Delta) / Double(total_Delta))
    }
}

/// Raw CPU counters for the whole machine and for every core.
public struct CPUSample: Codable, Equatable, Sendable {
    public let total: CPUTicks
    public let cores: [CPUTicks]

    public init(total: CPUTicks, cores: [CPUTicks]) {
        self.total = total
        self.cores = cores
    }
}

/// CPU load derived from two samples, as fractions in 0...1.
public struct CPUUsage: Codable, Equatable, Sendable {
    public let total_Fraction: Double
    public let core_Fractions: [Double]

    public init(from previous: CPUSample, to current: CPUSample) {
        total_Fraction = current.total.busyFraction(
            since: previous.total
        )
        let core_Pairs = zip(previous.cores, current.cores)
        core_Fractions = core_Pairs.map { old_Core, new_Core in
            new_Core.busyFraction(since: old_Core)
        }
    }
}
