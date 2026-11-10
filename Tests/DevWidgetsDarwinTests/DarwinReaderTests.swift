#if os(macOS)
import DevWidgetsCore
import Foundation
import Testing

@testable import DevWidgetsDarwin

/// Reads the Mac running the tests. Only facts every Mac has are
/// checked: a virtual machine may lack a GPU, a battery or disks.
struct DarwinReaderTests {
    @Test func readsThisMac() throws {
        let sample = try DarwinSampleReader().readSample()
        #expect(!sample.cpu.cores.isEmpty)
        #expect(sample.cpu.total.total_Ticks > 0)
        #expect(sample.memory.physical.total_Bytes > 0)
        #expect(sample.memory.physical.used_Fraction <= 1)
        #expect(sample.disk.space.total_Bytes > 0)
        #expect(!sample.processes.isEmpty)
    }

    @Test func sysctlReadsKnownNames() {
        #expect(readSysctl("hw.ncpu", default: Int32(0)) > 0)
        #expect(readSysctl("hw.memsize", default: UInt64(0)) > 0)
    }

    @Test func sysctlKeepsTheFallback() {
        let unknown = readSysctl("devwidgets.missing", default: 7)
        #expect(unknown == 7)
        // hw.ncpu is 4 bytes: an 8-byte request is incomplete.
        #expect(readSysctl("hw.ncpu", default: UInt64(9)) == 9)
    }

    @Test func processesIncludeThisOne() {
        let this_Process = ProcessInfo.processInfo.processIdentifier
        let processes = DarwinProcessReader.readProcesses()
        #expect(
            processes.contains { $0.identity.pid == this_Process }
        )
    }
}
#endif
