import Foundation

/// A `RawSample` together with the moment it was taken.
public struct TimedSample: Equatable, Sendable {
    public let sample: RawSample
    public let captured_At: Date

    public init(sample: RawSample, captured_At: Date) {
        self.sample = sample
        self.captured_At = captured_At
    }
}

/// Two consecutive samples and the seconds between them: what
/// every rate calculation needs.
public struct SampleInterval: Sendable {
    public let old_Sample: RawSample
    public let new_Sample: RawSample
    public let elapsed_Seconds: Double

    public init(from previous: TimedSample, to current: TimedSample) {
        old_Sample = previous.sample
        new_Sample = current.sample
        elapsed_Seconds = current.captured_At
            .timeIntervalSince(previous.captured_At)
    }
}

/// Current values of every metric family, ready to display.
public struct MetricReadings: Codable, Equatable, Sendable {
    public let cpu: CPUUsage
    public let memory: MemoryUsage
    public let disk: DiskUsage
    public let network: NetworkThroughput
    public let hardware: HardwareStatus
    public let top_Processes: [ProcessUsage]
    public let local_Address: String?

    public init(over interval: SampleInterval) {
        let new_Sample = interval.new_Sample
        cpu = CPUUsage(
            from: interval.old_Sample.cpu,
            to: new_Sample.cpu
        )
        memory = new_Sample.memory
        disk = DiskUsage(over: interval)
        network = NetworkThroughput(over: interval)
        hardware = new_Sample.hardware
        top_Processes = ProcessRanking.rankBusiest(
            from: interval.old_Sample.processes,
            to: new_Sample.processes,
            elapsed_Seconds: interval.elapsed_Seconds
        )
        local_Address = new_Sample.local_Address
    }
}

/// What the host app publishes to the widgets through the App Group.
public struct MetricSnapshot: Codable, Equatable, Sendable {
    public let captured_At: Date
    public let readings: MetricReadings
    public let history: MetricHistory
}
