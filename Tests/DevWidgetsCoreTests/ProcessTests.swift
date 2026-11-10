import Testing
@testable import DevWidgetsCore

struct ProcessTests {
    static let UNITS = KernelUnits(
        ticks_Per_Second: 100,
        page_Bytes: 4_096
    )

    @Test func statNameMayContainSpacesAndParentheses() throws {
        let stat_Text = try Fixtures.text("4242/stat")
        let counters = try #require(
            ProcessStatParser.parseCounters(
                stat_Text: stat_Text,
                units: Self.UNITS
            )
        )
        #expect(counters.identity.pid == 4242)
        #expect(counters.identity.name == "Web Content (2)")
        #expect(counters.cpu_Seconds == 3)
        #expect(counters.resident_Bytes == 2_048 * 4_096)
    }

    @Test func truncatedStatIsRejected() {
        let counters = ProcessStatParser.parseCounters(
            stat_Text: "12 (short) S 1 2 3",
            units: Self.UNITS
        )
        #expect(counters == nil)
    }

    @Test func fixtureTreeListsNumericDirectoriesOnly() {
        let process_Reader = LinuxProcessReader(
            proc_Directory: Fixtures.PROC_DIRECTORY
        )
        let process_IDs = process_Reader.readProcesses()
            .map(\.identity.pid)
            .sorted()
        #expect(process_IDs == [77, 4242])
    }

    @Test func rankingSortsByCPUThenMemory() {
        let previous = [
            makeCounters(pid: 1, cpu_Seconds: 10, megabytes: 100),
            makeCounters(pid: 2, cpu_Seconds: 10, megabytes: 300),
            makeCounters(pid: 3, cpu_Seconds: 10, megabytes: 200),
        ]
        let current = [
            makeCounters(pid: 1, cpu_Seconds: 12, megabytes: 100),
            makeCounters(pid: 2, cpu_Seconds: 11, megabytes: 300),
            makeCounters(pid: 3, cpu_Seconds: 11, megabytes: 200),
            makeCounters(pid: 4, cpu_Seconds: 99, megabytes: 1),
        ]
        let ranking = ProcessRanking.rankBusiest(
            from: previous,
            to: current,
            elapsed_Seconds: 2
        )
        #expect(ranking.map(\.identity.pid) == [1, 2, 3])
        #expect(ranking.first?.cpu_Fraction == 1)
    }

    @Test func reusedPidIsNotMatched() {
        let old_Counters = ProcessCounters(
            identity: ProcessIdentity(pid: 9, name: "old"),
            cpu_Seconds: 1,
            resident_Bytes: 1
        )
        let new_Counters = ProcessCounters(
            identity: ProcessIdentity(pid: 9, name: "new"),
            cpu_Seconds: 5,
            resident_Bytes: 1
        )
        let ranking = ProcessRanking.rankBusiest(
            from: [old_Counters],
            to: [new_Counters],
            elapsed_Seconds: 1
        )
        #expect(ranking.isEmpty)
    }

    @Test func rankingKeepsOnlyTheTopCount() {
        let counters = (1...9).map {
            makeCounters(pid: Int32($0), cpu_Seconds: 1, megabytes: 1)
        }
        let ranking = ProcessRanking.rankBusiest(
            from: counters,
            to: counters,
            elapsed_Seconds: 1
        )
        #expect(ranking.count == ProcessRanking.TOP_COUNT)
    }

    func makeCounters(
        pid: Int32,
        cpu_Seconds: Double,
        megabytes: UInt64
    ) -> ProcessCounters {
        ProcessCounters(
            identity: ProcessIdentity(pid: pid, name: "p\(pid)"),
            cpu_Seconds: cpu_Seconds,
            resident_Bytes: megabytes << 20
        )
    }
}
