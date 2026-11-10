import DevWidgetsCore
import Foundation

/// Plausible snapshot for placeholders and Xcode previews, built
/// through the real recorder so it can never drift from the model.
enum PreviewData {
    static let SNAPSHOT: MetricSnapshot? = makeSnapshot()
    static let GIGABYTE: UInt64 = 1 << 30
    static let BUSY_PERCENT: UInt64 = 42
    static let CORE_COUNT = 10

    /// A minute of history so the gallery's charts have a shape.
    static let HISTORY_SECONDS = 60

    static func makeSnapshot() -> MetricSnapshot? {
        var recorder = MetricsRecorder()
        var totals = PreviewTotals()
        let start_Date = Date().addingTimeInterval(
            -Double(HISTORY_SECONDS)
        )
        var snapshot: MetricSnapshot?
        for second in 0...HISTORY_SECONDS {
            totals.advance(seconds_Left: HISTORY_SECONDS - second)
            snapshot = recorder.record(
                TimedSample(
                    sample: makeSample(totals),
                    captured_At: start_Date.addingTimeInterval(
                        Double(second)
                    )
                )
            )
        }
        return snapshot
    }

    static func makeSample(_ totals: PreviewTotals) -> RawSample {
        let ticks = CPUTicks(
            busy_Ticks: totals.busy_Ticks,
            idle_Ticks: totals.elapsed_Ticks - totals.busy_Ticks
        )
        let core_Ticks = Array(repeating: ticks, count: CORE_COUNT)
        var sample = RawSample(
            cpu: CPUSample(total: ticks, cores: core_Ticks),
            memory: makeMemory(used_Bytes: totals.memory_Bytes),
            disk: DiskSample(space: DISK_SPACE, io_Counters: nil),
            network: NetworkCounters(
                received_Bytes: totals.network_Bytes,
                sent_Bytes: totals.network_Bytes / 5
            )
        )
        sample.hardware = HARDWARE
        sample.processes = makeProcesses(
            elapsed_Ticks: totals.elapsed_Ticks
        )
        sample.local_Address = "192.168.1.20"
        return sample
    }

    static let DISK_SPACE = Capacity(
        used_Bytes: 310 * GIGABYTE,
        total_Bytes: 494 * GIGABYTE
    )

    static let HARDWARE = HardwareStatus(
        gpu_Fraction: 0.31,
        thermal: ThermalReading(level: .normal, celsius: nil),
        battery: BatteryState(
            charge_Fraction: 0.76,
            power_Source: .battery,
            minutes_Remaining: 245
        )
    )

    /// CPU seconds grow with the ticks so the second sample ranks
    /// swift-frontend first, Xcode second.
    static func makeProcesses(
        elapsed_Ticks: UInt64
    ) -> [ProcessCounters] {
        let elapsed_Seconds = Double(elapsed_Ticks) / 1_000
        let busy_Programs = [
            PreviewProgram(name: "swift-frontend", cores: 1.8),
            PreviewProgram(name: "Xcode", cores: 0.4),
            PreviewProgram(name: "Simulator", cores: 0.2),
            PreviewProgram(name: "node", cores: 0.15),
            PreviewProgram(name: "Docker", cores: 0.1),
        ]
        return busy_Programs.enumerated().map { index, program in
            ProcessCounters(
                identity: ProcessIdentity(
                    pid: Int32(500 + index),
                    name: program.name
                ),
                cpu_Seconds: program.cores * elapsed_Seconds,
                resident_Bytes: GIGABYTE * UInt64(5 - index) / 2
            )
        }
    }

    static func makeMemory(used_Bytes: UInt64) -> MemoryUsage {
        MemoryUsage(
            physical: Capacity(
                used_Bytes: used_Bytes,
                total_Bytes: 16 * GIGABYTE
            ),
            swap: Capacity(
                used_Bytes: GIGABYTE,
                total_Bytes: 2 * GIGABYTE
            ),
            pressure: .elevated
        )
    }
}

/// Cumulative counters of the made-up machine. Load and traffic
/// wave over the minute and end at 42 % CPU, 11 GB of memory and
/// 2.5 MB/s down, the values the gallery shows.
struct PreviewTotals {
    static let TICKS_PER_SECOND: UInt64 = 1_000
    static let END_RATE_BYTES = 2_500_000.0
    static let WAVE_SECONDS = 7.0

    var elapsed_Ticks: UInt64 = 0
    var busy_Ticks: UInt64 = 0
    var network_Bytes: UInt64 = 0
    var memory_Bytes = 11 * PreviewData.GIGABYTE

    mutating func advance(seconds_Left: Int) {
        let wave = sin(Double(seconds_Left) / Self.WAVE_SECONDS)
        let busy_Percent =
            Double(PreviewData.BUSY_PERCENT)
            + 25 * wave
        elapsed_Ticks += Self.TICKS_PER_SECOND
        busy_Ticks += UInt64(busy_Percent * 10)
        network_Bytes += UInt64(
            Self.END_RATE_BYTES * (1 + 0.6 * sin(1.3 * wave))
        )
        let memory_Change = Double(PreviewData.GIGABYTE) * wave
        memory_Bytes = UInt64(
            Double(11 * PreviewData.GIGABYTE) + memory_Change
        )
    }
}

/// A made-up busy program for previews.
struct PreviewProgram {
    let name: String
    /// CPU use where 1.0 is one full core.
    let cores: Double
}
