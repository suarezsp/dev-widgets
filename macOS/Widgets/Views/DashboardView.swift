import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Large: CPU history, memory and network side by side, top four
/// processes. Extra large adds the hardware tiles and top five.
struct DashboardView: View {
    static let LARGE_PROCESS_COUNT = 4

    @LayoutFamily private var widget_Family

    let snapshot: MetricSnapshot
    let armed_Action: WidgetAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardHeader(snapshot: snapshot)
            if widget_Family == .systemExtraLarge {
                HStack(alignment: .top, spacing: 16) {
                    chart_Stack
                    side_Column
                }
            } else {
                chart_Stack
                processList(row_Limit: Self.LARGE_PROCESS_COUNT)
            }
        }
    }

    private var chart_Stack: some View {
        VStack(spacing: 10) {
            chart(.cpu)
            HStack(spacing: 12) {
                chart(.memory)
                chart(.network)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var side_Column: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(DashboardView.SIDE_KINDS, id: \.self) { kind in
                MetricRow(
                    presentation: kind.present(snapshot.readings)
                )
            }
            processList(row_Limit: ProcessRanking.TOP_COUNT)
        }
        .frame(maxWidth: .infinity)
    }

    /// Each row has a quit button (tap twice to confirm).
    private func processList(row_Limit: Int) -> some View {
        ProcessList(
            processes: snapshot.readings.top_Processes,
            row_Limit: row_Limit
        ) {
            WidgetActionButton(
                process: $0.identity,
                armed_Action: armed_Action
            )
        }
    }

    private func chart(_ kind: MetricKind) -> some View {
        HistoryChart(
            presentation: kind.present(snapshot.readings),
            series: snapshot.history.series(for: kind)
        )
    }
}

extension DashboardView {
    static let SIDE_KINDS: [MetricKind] = [
        .disk, .gpu, .thermal, .battery,
    ]
}

/// App name, local IP and the time of the shown sample.
struct DashboardHeader: View {
    let snapshot: MetricSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Label(
                "DEVWIDGETS",
                systemImage: "gauge.with.dots.needle.50percent"
            )
            .labelStyle(CompactLabelStyle())
            .widgetAccentable()
            Spacer(minLength: 4)
            if let local_Address = snapshot.readings.local_Address {
                Label(local_Address, systemImage: "wifi")
                    .labelStyle(CompactLabelStyle())
                    .monospacedDigit()
            }
            Text(snapshot.captured_At, style: .time)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}
