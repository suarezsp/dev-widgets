import Foundation

/// Turns a stream of raw samples into snapshots with history.
/// The first sample only primes the recorder: rates need two.
public struct MetricsRecorder: Sendable {
    private var previous_Sample: TimedSample?
    private var history = MetricHistory()

    public init() {}

    public mutating func record(
        _ sample: TimedSample
    ) -> MetricSnapshot? {
        guard let last_Sample = previous_Sample else {
            previous_Sample = sample
            return nil
        }
        previous_Sample = sample
        let readings = MetricReadings(
            over: SampleInterval(from: last_Sample, to: sample)
        )
        history.append(readings)
        return MetricSnapshot(
            captured_At: sample.captured_At,
            readings: readings,
            history: history
        )
    }
}

/// Platform-independent sampling entry point shared by the macOS
/// menu bar app and the Linux probe (and later the Linux UI).
public struct MetricsMonitor<Reader: RawSampleReader>: Sendable {
    private let reader: Reader
    private var recorder = MetricsRecorder()

    public init(reader: Reader) {
        self.reader = reader
    }

    /// Reads the machine now; nil until two samples exist.
    public mutating func sample(
        at capture_Date: Date = Date()
    ) throws -> MetricSnapshot? {
        let raw_Sample = try reader.readSample()
        let timed_Sample = TimedSample(
            sample: raw_Sample,
            captured_At: capture_Date
        )
        return recorder.record(timed_Sample)
    }
}
