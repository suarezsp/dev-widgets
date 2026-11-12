import Charts
import DevWidgetsCore
import SwiftUI
import WidgetKit

/// One line of a history chart, e.g. download or upload.
struct ChartSeries: Identifiable {
    let name: String
    let values: [Double]
    var id: String { name }
}

/// Last minutes of one metric as a filled line chart. Shares are
/// drawn on a fixed 0–100 % scale, rates on a scale that follows
/// the peak.
struct HistoryChart: View {
    static let FILL_OPACITY = 0.22

    /// The clear and tinted presentations draw the lines only:
    /// Apple keeps translucent fills for the full-color one.
    @Environment(\.widgetRenderingMode) private var rendering_Mode

    let presentation: MetricPresentation
    let series: [ChartSeries]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                MetricHeader(presentation: presentation)
                Spacer(minLength: 4)
                Text(presentation.value_Text)
                    .font(
                        .title3.weight(.semibold).monospacedDigit()
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            chart
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.spoken_Text)
        .accessibilityValue(summary_Text)
    }

    /// One sentence per line: its lowest and highest value.
    private var summary_Text: String {
        series.compactMap {
            HistorySummary.describe(
                name: $0.name,
                values: $0.values,
                is_Share: presentation.fraction != nil
            )
        }
        .joined(separator: ". ")
    }

    private var chart: some View {
        Chart(series) { line in
            ForEach(Array(line.values.enumerated()), id: \.offset) {
                marks(
                    sample_Index: $0.offset,
                    value: $0.element,
                    line
                )
            }
        }
        .chartForegroundStyleScale(
            domain: series.map(\.name),
            range: Array(series_Colors.prefix(series.count))
        )
        .chartLegend(series.count > 1 ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .trailing)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...upper_Bound)
        .widgetAccentable()
    }

    /// Unstacked, so upload is drawn over download, not on top.
    @ChartContentBuilder
    private func marks(
        sample_Index: Int,
        value: Double,
        _ line: ChartSeries
    ) -> some ChartContent {
        if rendering_Mode == .fullColor {
            AreaMark(
                x: .value("Sample", sample_Index),
                y: .value("Value", value),
                stacking: .unstacked
            )
            .foregroundStyle(by: .value("Series", line.name))
            .opacity(Self.FILL_OPACITY)
        }
        LineMark(
            x: .value("Sample", sample_Index),
            y: .value("Value", value)
        )
        .foregroundStyle(by: .value("Series", line.name))
    }

    private var series_Colors: [Color] {
        [presentation.level.tint, .secondary]
    }

    private var upper_Bound: Double {
        guard presentation.fraction == nil else { return 1 }
        let peak = series.flatMap(\.values).max() ?? 0
        return max(peak, 1)
    }
}

extension MetricHistory {
    func series(for kind: MetricKind) -> [ChartSeries] {
        switch kind {
        case .cpu: [ChartSeries(name: "CPU", values: cpu_Fractions)]
        case .memory:
            [
                ChartSeries(
                    name: String(localized: "Memory"),
                    values: memory_Fractions
                )
            ]
        case .network:
            [
                ChartSeries(
                    name: String(localized: "Down"),
                    values: download_Rates
                ),
                ChartSeries(
                    name: String(localized: "Up"),
                    values: upload_Rates
                ),
            ]
        default: []
        }
    }
}
