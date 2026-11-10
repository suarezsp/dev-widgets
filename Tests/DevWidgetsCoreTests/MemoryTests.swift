import Testing
@testable import DevWidgetsCore

struct MemoryTests {
    @Test func meminfoUsesAvailableMemoryAsFree() throws {
        let meminfo_Text = try Fixtures.text("meminfo")
        let memory = try #require(
            MemInfoParser.parseMemory(
                meminfo_Text: meminfo_Text,
                pressure_Level: nil
            )
        )
        let kibibyte = MemInfoParser.BYTES_PER_KIBIBYTE
        #expect(memory.physical.total_Bytes == 16_384_000 * kibibyte)
        #expect(memory.physical.used_Bytes == 12_288_000 * kibibyte)
        #expect(memory.swap.used_Bytes == 512_000 * kibibyte)
    }

    @Test func pressureFallsBackToUsedShare() throws {
        let meminfo_Text = try Fixtures.text("meminfo")
        let memory = MemInfoParser.parseMemory(
            meminfo_Text: meminfo_Text,
            pressure_Level: nil
        )
        #expect(memory?.pressure == .elevated)
    }

    @Test func explicitPressureWins() throws {
        let memory = MemInfoParser.parseMemory(
            meminfo_Text: try Fixtures.text("meminfo"),
            pressure_Level: .critical
        )
        #expect(memory?.pressure == .critical)
    }

    @Test func meminfoWithoutTotalsIsRejected() {
        let partial_Text = "MemFree: 10 kB\n"
        let memory = MemInfoParser.parseMemory(
            meminfo_Text: partial_Text,
            pressure_Level: nil
        )
        #expect(memory == nil)
    }

    @Test func unitlessFieldsAreKeptAsIs() {
        let fields = MemInfoParser.parseFields("HugePages_Total: 7\n")
        #expect(fields["HugePages_Total"] == 7)
    }

    @Test func pressureStallIsGradedFromSomeAverage() throws {
        let pressure_Text = try Fixtures.text("pressure/memory")
        let level = PressureStallParser.parseLevel(
            from: pressure_Text
        )
        #expect(level == .elevated)
    }

    @Test func calmPressureIsNormal() {
        let calm_Text =
            "some avg10=0.00 avg60=0.00 avg300=0.00 total=0"
        #expect(
            PressureStallParser.parseLevel(from: calm_Text) == .normal
        )
    }

    @Test func malformedPressureIsIgnored() {
        #expect(
            PressureStallParser.parseLevel(from: "some x=1") == nil
        )
    }
}
