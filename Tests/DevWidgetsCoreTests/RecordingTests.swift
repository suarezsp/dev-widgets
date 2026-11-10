import Foundation
import Testing
@testable import DevWidgetsCore

struct RecordingTests {
    @Test func firstSampleOnlyPrimesTheRecorder() {
        var recorder = MetricsRecorder()
        let sample = SampleFactory.makeSample(
            busy_Ticks: 0,
            received_Bytes: 0,
            read_Bytes: 0
        )
        let timed_Sample = SampleFactory.makeTimedSample(
            sample,
            seconds_After_Start: 0
        )
        #expect(recorder.record(timed_Sample) == nil)
    }

    @Test func secondSampleProducesRatesAndTrends() throws {
        let snapshot = try #require(recordTwoSecondsOfWork())
        let readings = snapshot.readings
        #expect(readings.network.download_Bytes_Per_Second == 1_000)
        #expect(
            readings.disk.throughput?.read_Bytes_Per_Second == 2_000
        )
        #expect(snapshot.history.cpu_Fractions == [1])
        #expect(snapshot.history.memory_Fractions == [0.5])
    }

    /// Two samples 2 s apart: CPU fully busy, 2 kB received,
    /// 4 kB read from disk.
    func recordTwoSecondsOfWork() -> MetricSnapshot? {
        var recorder = MetricsRecorder()
        let first_Sample = SampleFactory.makeSample(
            busy_Ticks: 0,
            received_Bytes: 0,
            read_Bytes: 0
        )
        let second_Sample = SampleFactory.makeSample(
            busy_Ticks: 1_000,
            received_Bytes: 2_000,
            read_Bytes: 4_000
        )
        _ = recorder.record(
            SampleFactory.makeTimedSample(
                first_Sample,
                seconds_After_Start: 0
            )
        )
        return recorder.record(
            SampleFactory.makeTimedSample(
                second_Sample,
                seconds_After_Start: 2
            )
        )
    }

    @Test func busiestProcessesAreRanked() throws {
        let first_Sample = makeSample(swift_Build_Seconds: 1)
        let second_Sample = makeSample(swift_Build_Seconds: 4)
        let readings = MetricReadings(
            over: SampleFactory.makeInterval(
                from: first_Sample,
                to: second_Sample,
                elapsed_Seconds: 2
            )
        )
        let busiest = try #require(readings.top_Processes.first)
        #expect(busiest.identity.name == "swift-build")
        #expect(busiest.cpu_Fraction == 1.5)
    }

    func makeSample(swift_Build_Seconds: Double) -> RawSample {
        var sample = SampleFactory.makeSample(
            busy_Ticks: 0,
            received_Bytes: 0,
            read_Bytes: 0
        )
        sample.processes = [
            ProcessCounters(
                identity: ProcessIdentity(
                    pid: 7,
                    name: "swift-build"
                ),
                cpu_Seconds: swift_Build_Seconds,
                resident_Bytes: 1
            )
        ]
        return sample
    }

    @Test func historyIsCappedAtCapacity() throws {
        var recorder = MetricsRecorder()
        let sample = SampleFactory.makeSample(
            busy_Ticks: 0,
            received_Bytes: 0,
            read_Bytes: nil
        )
        var latest_Snapshot: MetricSnapshot?
        for second in 0...(MetricHistory.CAPACITY + 10) {
            latest_Snapshot = recorder.record(
                SampleFactory.makeTimedSample(
                    sample,
                    seconds_After_Start: Double(second)
                )
            )
        }
        let history = try #require(latest_Snapshot?.history)
        let capacity = MetricHistory.CAPACITY
        #expect(history.cpu_Fractions.count == capacity)
    }

    @Test func monitorSamplesThroughItsReader() throws {
        var monitor = MetricsMonitor(reader: FixedSampleReader())
        let start_Date = Date(timeIntervalSinceReferenceDate: 0)
        #expect(try monitor.sample(at: start_Date) == nil)
        let snapshot = try monitor.sample(
            at: start_Date.addingTimeInterval(1)
        )
        #expect(
            snapshot?.captured_At == start_Date.addingTimeInterval(1)
        )
    }

    @Test func monitorPropagatesReaderErrors() {
        var monitor = MetricsMonitor(reader: FailingSampleReader())
        #expect(throws: SampleReadError.self) {
            try monitor.sample()
        }
    }
}

struct FixedSampleReader: RawSampleReader {
    func readSample() throws -> RawSample {
        SampleFactory.makeSample(
            busy_Ticks: 10,
            received_Bytes: 10,
            read_Bytes: nil
        )
    }
}

struct FailingSampleReader: RawSampleReader {
    func readSample() throws -> RawSample {
        throw SampleReadError.unreadable(path: "/nowhere")
    }
}
