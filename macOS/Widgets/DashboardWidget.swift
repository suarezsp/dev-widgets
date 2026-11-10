import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Large and extra-large widget with history charts. It shows a
/// fixed set of metrics, so it needs no configuration intent.
struct DashboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppGroup.DASHBOARD_KIND,
            provider: DashboardTimelineProvider()
        ) { entry in
            DashboardWidgetView(
                snapshot: entry.snapshot,
                armed_Action: entry.armed_Action
            )
        }
        .configurationDisplayName("Developer Dashboard")
        .description(
            "History charts, hardware and top processes to quit."
        )
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot?
    var armed_Action: WidgetAction?
}

struct DashboardTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), snapshot: PreviewData.SNAPSHOT)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DashboardEntry) -> Void
    ) {
        let snapshot = SnapshotLoader.loadSnapshot(
            allows_Preview_Data: context.isPreview
        )
        completion(DashboardEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DashboardEntry>) -> Void
    ) {
        let snapshot = SnapshotLoader.loadSnapshot(
            allows_Preview_Data: false
        )
        let entries = ArmedActionTimeline.makeDates().map {
            DashboardEntry(
                date: $0.date,
                snapshot: snapshot,
                armed_Action: $0.armed
            )
        }
        completion(
            Timeline(
                entries: entries,
                policy: .after(SnapshotLoader.nextFallbackDate())
            )
        )
    }
}

struct DashboardWidgetView: View {
    let snapshot: MetricSnapshot?
    let armed_Action: WidgetAction?

    var body: some View {
        Group {
            if let snapshot {
                DashboardView(
                    snapshot: snapshot,
                    armed_Action: armed_Action
                )
            } else {
                WaitingForDataView()
            }
        }
        .systemWidgetBackground()
    }
}
