import Testing
@testable import DevWidgetsCore

struct LoadAndCapacityTests {
    @Test(arguments: [
        (0.0, LoadLevel.normal), (0.59, .normal),
        (0.6, .elevated), (0.84, .elevated),
        (0.85, .critical), (1.0, .critical),
    ])
    func defaultThresholds(
        fraction: Double,
        expected_Level: LoadLevel
    ) {
        let level = LoadThresholds.DEFAULT.level(for: fraction)
        #expect(level == expected_Level)
    }

    @Test func capacityReportsFreeAndUsedShare() {
        let capacity = Capacity(used_Bytes: 25, total_Bytes: 100)
        #expect(capacity.free_Bytes == 75)
        #expect(capacity.used_Fraction == 0.25)
    }

    @Test func capacityClampsUsedToTotal() {
        let capacity = Capacity(used_Bytes: 150, total_Bytes: 100)
        #expect(capacity.used_Bytes == 100)
        #expect(capacity.free_Bytes == 0)
    }

    @Test func emptyCapacityHasZeroShare() {
        let capacity = Capacity(used_Bytes: 0, total_Bytes: 0)
        #expect(capacity.used_Fraction == 0)
    }
}
