/// The last minutes of the values the widget charts draw.
public struct MetricHistory: Codable, Equatable, Sendable {
    /// Five minutes at the host app's one-second sampling rate.
    public static let CAPACITY = 300

    private var cpu_Buffer = RingBuffer<Double>(capacity: CAPACITY)
    private var memory_Buffer = RingBuffer<Double>(capacity: CAPACITY)
    private var download_Buffer = RingBuffer<Double>(
        capacity: CAPACITY
    )
    private var upload_Buffer = RingBuffer<Double>(capacity: CAPACITY)

    public init() {}

    // Oldest first.
    public var cpu_Fractions: [Double] { cpu_Buffer.ordered_Elements }
    public var memory_Fractions: [Double] {
        memory_Buffer.ordered_Elements
    }
    /// Bytes per second.
    public var download_Rates: [Double] {
        download_Buffer.ordered_Elements
    }
    public var upload_Rates: [Double] {
        upload_Buffer.ordered_Elements
    }

    public mutating func append(_ readings: MetricReadings) {
        cpu_Buffer.append(readings.cpu.total_Fraction)
        memory_Buffer.append(readings.memory.physical.used_Fraction)
        download_Buffer.append(
            readings.network.download_Bytes_Per_Second
        )
        upload_Buffer.append(readings.network.upload_Bytes_Per_Second)
    }
}
