/// Everything a platform reader collects in one pass. Counters are
/// cumulative; `MetricReadings` turns two samples into rates.
public struct RawSample: Equatable, Sendable {
    public let cpu: CPUSample
    public let memory: MemoryUsage
    public let disk: DiskSample
    public let network: NetworkCounters
    /// Optional families: readers fill what the machine has.
    public var hardware = HardwareStatus.UNKNOWN
    public var processes: [ProcessCounters] = []
    public var local_Address: String?

    // style:allow-params one argument per metric family every
    // machine has; grouping them would add a type with no meaning.
    public init(
        cpu: CPUSample,
        memory: MemoryUsage,
        disk: DiskSample,
        network: NetworkCounters
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
    }
}

/// Anything able to take a `RawSample` of the current machine.
/// Implemented by the Linux reader, the Darwin reader and tests.
public protocol RawSampleReader: Sendable {
    func readSample() throws -> RawSample
}
