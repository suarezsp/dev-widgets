import Foundation
import Testing
@testable import DevWidgetsCore

struct SnapshotStoreTests {
    @Test func savedSnapshotLoadsBackUnchanged() throws {
        let store = SnapshotStore(
            directory: try makeTemporaryDirectory()
        )
        let snapshot = try makeSnapshot()
        try store.save(snapshot)
        #expect(try store.load() == snapshot)
    }

    @Test func emptyStoreLoadsNil() throws {
        let store = SnapshotStore(
            directory: try makeTemporaryDirectory()
        )
        #expect(try store.load() == nil)
    }

    @Test func corruptFileThrows() throws {
        let store = SnapshotStore(
            directory: try makeTemporaryDirectory()
        )
        try Data("not json".utf8).write(to: store.file_URL)
        #expect(throws: DecodingError.self) { try store.load() }
    }

    func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    func makeSnapshot() throws -> MetricSnapshot {
        var monitor = MetricsMonitor(reader: FixedSampleReader())
        _ = try monitor.sample(at: Date(timeIntervalSince1970: 0))
        let snapshot = try monitor.sample(
            at: Date(timeIntervalSince1970: 1.25)
        )
        return try #require(snapshot)
    }
}

struct MetricFormattingTests {
    @Test(arguments: [
        (1.5, 1, ("es", "1,5")), (1.5, 1, ("en", "1.5")),
        (1234.5, 2, ("es", "1234,50")),
    ])
    func decimalsFollowTheDisplayLanguage(
        value: Double,
        digits: Int,
        expected: (language: String, text: String)
    ) {
        let text = DisplayLocale.formatDecimal(
            value,
            digits: digits,
            locale: Locale(identifier: expected.language)
        )
        #expect(text == expected.text)
    }

    @Test(arguments: [
        (0.0, "0 B"), (512.0, "512 B"), (1_536.0, "1.5 KB"),
        (52_428_800.0, "50 MB"), (17_179_869_184.0, "16 GB"),
        (-5.0, "0 B"),
    ])
    func describesBytes(byte_Count: Double, expected_Text: String) {
        let text = MetricFormatting.describe(bytes: byte_Count)
        #expect(text == expected_Text)
    }

    @Test func describesRates() {
        let text = MetricFormatting.describeRate(
            bytes_Per_Second: 2_048
        )
        #expect(text == "2.0 KB/s")
    }

    @Test(arguments: [
        (0.423, "42%"), (1.7, "100%"), (-0.2, "0%"),
    ])
    func describesPercent(fraction: Double, expected_Text: String) {
        let text = MetricFormatting.describePercent(
            fraction: fraction
        )
        #expect(text == expected_Text)
    }

    @Test func processShareMayExceedOneCore() {
        #expect(MetricFormatting.describeCoreShare(1.524) == "152%")
        #expect(MetricFormatting.describeCoreShare(-1) == "0%")
    }

    @Test func describesCelsius() {
        #expect(MetricFormatting.describeCelsius(72.6) == "73 °C")
    }

    @Test(arguments: [
        (45, "45 min"), (125, "2 h 05 min"), (-3, "0 min"),
    ])
    func describesMinutes(minutes: Int, expected_Text: String) {
        let text = MetricFormatting.describeMinutes(minutes)
        #expect(text == expected_Text)
    }
}
