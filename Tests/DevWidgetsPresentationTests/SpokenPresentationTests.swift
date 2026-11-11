import DevWidgetsCore
import Testing
@testable import DevWidgetsPresentation

/// What VoiceOver reads instead of rings, bars, charts and colors.
struct SpokenPresentationTests {
    @Test func healthyMetricReadsNameValueAndDetail() {
        let cpu = MetricPresentation(
            kind: .cpu,
            value_Text: "42%",
            detail_Text: "8 cores"
        )
        #expect(cpu.spoken_Text == "CPU, 42%, 8 cores")
    }

    @Test func warningIsSpokenNotOnlyColored() {
        let memory = MetricPresentation(
            kind: .memory,
            value_Text: "91%",
            detail_Text: "14.6 GB of 16 GB"
        )
        .with(level: .critical, fraction: 0.91)
        #expect(memory.spoken_Text.hasSuffix(", critical"))
    }

    @Test func networkArrowsAreReadAsWords() {
        let network = MetricPresentation(
            kind: .network,
            value_Text: "↓ 1.2 MB/s",
            detail_Text: "↑ 80 KB/s"
        )
        #expect(network.spoken_Text.contains("download 1.2 MB/s"))
        #expect(network.spoken_Text.contains("upload 80 KB/s"))
    }

    @Test func missingSensorSaysSo() {
        let battery = MetricPresentation.makeUnavailable(.battery)
        #expect(battery.spoken_Text.hasSuffix(", not available"))
    }

    @Test func serverLineReadsEveryGaugeAndItsLevel() {
        let line = ServerLine(
            alias: "web-1",
            detail_Text: "up 3 days",
            level: .elevated,
            gauges: [
                ServerGauge(title: "CPU", fraction: 0.12),
                ServerGauge(title: "Disk", fraction: 0.8),
            ]
        )
        #expect(line.spoken_Text.hasPrefix("web-1, up 3 days, CPU"))
        #expect(line.spoken_Text.hasSuffix(", high"))
    }

    @Test func chartIsSummarizedByItsRange() throws {
        let summary = try #require(
            HistorySummary.describe(
                name: "CPU",
                values: [0.2, 0.05, 0.8],
                is_Share: true
            )
        )
        #expect(summary.hasPrefix("CPU: lowest 5"))
        #expect(summary.contains("highest 80"))
        #expect(
            HistorySummary.describe(
                name: "Up",
                values: [],
                is_Share: false
            ) == nil
        )
    }
}
