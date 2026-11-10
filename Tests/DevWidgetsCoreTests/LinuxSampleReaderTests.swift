import Foundation
import Testing
@testable import DevWidgetsCore

struct LinuxSampleReaderTests {
    @Test func readsEveryFamilyFromFixtures() throws {
        let reader = LinuxSampleReader(
            proc_Directory: Fixtures.PROC_DIRECTORY,
            sys_Directory: Fixtures.SYS_DIRECTORY
        )
        let sample = try reader.readSample()
        #expect(sample.hardware.gpu_Fraction == 0.37)
        #expect(sample.processes.count == 2)
        #expect(sample.cpu.cores.count == 2)
        #expect(sample.memory.pressure == .elevated)
        #expect(sample.disk.io_Counters != nil)
        #expect(sample.network.sent_Bytes == 1_500_000)
    }

    @Test func missingProcTreeThrowsUnreadable() {
        let reader = LinuxSampleReader(
            proc_Directory: URL(fileURLWithPath: "/no/such/proc")
        )
        #expect(throws: SampleReadError.self) {
            try reader.readSample()
        }
    }

    #if os(Linux)
    @Test func readsThisMachine() throws {
        var monitor = MetricsMonitor(reader: LinuxSampleReader())
        _ = try monitor.sample()
        let snapshot = try #require(try monitor.sample())
        let readings = snapshot.readings
        #expect(readings.memory.physical.total_Bytes > 0)
        #expect(!readings.cpu.core_Fractions.isEmpty)
        #expect((0...1).contains(readings.cpu.total_Fraction))
    }
    #endif
}
