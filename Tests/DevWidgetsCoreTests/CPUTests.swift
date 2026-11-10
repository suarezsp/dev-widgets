import Testing
@testable import DevWidgetsCore

struct CPUTests {
    @Test func busyFractionUsesTickDeltas() {
        let previous = CPUTicks(busy_Ticks: 100, idle_Ticks: 100)
        let current = CPUTicks(busy_Ticks: 175, idle_Ticks: 125)
        #expect(current.busyFraction(since: previous) == 0.75)
    }

    @Test func busyFractionIsZeroWithoutElapsedTicks() {
        let ticks = CPUTicks(busy_Ticks: 10, idle_Ticks: 10)
        #expect(ticks.busyFraction(since: ticks) == 0)
    }

    @Test func busyFractionIsZeroWhenCountersGoBackwards() {
        let previous = CPUTicks(busy_Ticks: 500, idle_Ticks: 10)
        let current = CPUTicks(busy_Ticks: 20, idle_Ticks: 900)
        #expect(current.busyFraction(since: previous) == 0)
    }

    @Test func ticksAddUp() {
        let core_Ticks = CPUTicks(busy_Ticks: 3, idle_Ticks: 4)
        let total_Ticks = [core_Ticks, core_Ticks].reduce(.ZERO, +)
        #expect(total_Ticks == CPUTicks(busy_Ticks: 6, idle_Ticks: 8))
    }

    @Test func usageComputesEveryCore() {
        let idle_Core = CPUTicks(busy_Ticks: 0, idle_Ticks: 10)
        let busy_Core = CPUTicks(busy_Ticks: 10, idle_Ticks: 10)
        let previous = CPUSample(
            total: CPUTicks(busy_Ticks: 0, idle_Ticks: 20),
            cores: [idle_Core, idle_Core]
        )
        let current = CPUSample(
            total: CPUTicks(busy_Ticks: 10, idle_Ticks: 30),
            cores: [
                busy_Core, CPUTicks(busy_Ticks: 0, idle_Ticks: 20),
            ]
        )
        let usage = CPUUsage(from: previous, to: current)
        #expect(usage.total_Fraction == 0.5)
        #expect(usage.core_Fractions == [1, 0])
    }

    @Test func procStatParsesTotalAndCores() throws {
        let stat_Text = try Fixtures.text("stat")
        let sample = try #require(
            ProcStatParser.parseCPUSample(from: stat_Text)
        )
        #expect(sample.cores.count == 2)
        #expect(sample.total.idle_Ticks == 3699 + 23)
        #expect(sample.total.busy_Ticks == 4705 + 356 + 584 + 59)
    }

    @Test func procStatWithoutAggregateLineIsRejected() {
        let core_Only_Text = "cpu0 1 2 3 4 5 6 7 8\n"
        #expect(
            ProcStatParser.parseCPUSample(from: core_Only_Text) == nil
        )
    }

    @Test func procStatSkipsShortLines() {
        let short_Text = "cpu 1 2\ncpu0 1 2 3 4\n"
        #expect(
            ProcStatParser.parseCPUSample(from: short_Text) == nil
        )
    }
}
