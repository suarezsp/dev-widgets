import Testing
@testable import DevWidgetsCore

struct DiskTests {
    @Test func diskstatsSumsWholeDisksOnly() throws {
        let stats_Text = try Fixtures.text("diskstats")
        let counters = try #require(
            DiskStatsParser.parseCounters(from: stats_Text)
        )
        let sector_Bytes = DiskStatsParser.SECTOR_BYTES
        #expect(
            counters.read_Bytes == (400_000 + 1_000) * sector_Bytes
        )
        #expect(
            counters.written_Bytes == (600_000 + 3_000) * sector_Bytes
        )
    }

    @Test(arguments: [
        ("sda", true), ("sda1", false), ("vdb", true),
        ("nvme0n1", true), ("nvme0n1p2", false),
        ("mmcblk0", true), ("mmcblk0p1", false), ("loop0", false),
    ])
    func wholeDiskNames(device_Name: String, is_Whole: Bool) {
        let name = Substring(device_Name)
        #expect(DiskStatsParser.isWholeDisk(name) == is_Whole)
    }

    @Test func diskstatsWithoutDisksIsNil() {
        let loop_Only_Text = "7 0 loop0 1 0 2 0 0 0 0 0 0 0 0"
        #expect(
            DiskStatsParser.parseCounters(from: loop_Only_Text) == nil
        )
    }

    @Test func throughputDividesByElapsedTime() {
        let previous = DiskIOCounters(read_Bytes: 0, written_Bytes: 0)
        let current = DiskIOCounters(
            read_Bytes: 800,
            written_Bytes: 200
        )
        let throughput = DiskThroughput(
            from: previous,
            to: current,
            elapsed_Seconds: 2
        )
        #expect(throughput.read_Bytes_Per_Second == 400)
        #expect(throughput.write_Bytes_Per_Second == 100)
    }

    @Test func usageHasNoThroughputWithoutCounters() {
        let sample = SampleFactory.makeSample(
            busy_Ticks: 0,
            received_Bytes: 0,
            read_Bytes: nil
        )
        let interval = SampleFactory.makeInterval(
            from: sample,
            to: sample,
            elapsed_Seconds: 1
        )
        let usage = DiskUsage(over: interval)
        #expect(usage.throughput == nil)
        #expect(usage.space == sample.disk.space)
    }

    @Test func rootVolumeHasSpace() throws {
        let space = try FileSystemSpace.capacity(at: "/")
        #expect(space.total_Bytes > 0)
        #expect(space.used_Bytes <= space.total_Bytes)
    }

    @Test func missingVolumeThrows() {
        #expect(throws: SampleReadError.self) {
            try FileSystemSpace.capacity(at: "/definitely/not/here")
        }
    }
}
