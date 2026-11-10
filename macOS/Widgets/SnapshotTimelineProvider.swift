import DevWidgetsCore
import WidgetKit

struct MetricEntry: TimelineEntry {
    let date: Date
    /// nil until the menu bar app has published its first snapshot.
    let snapshot: MetricSnapshot?
    let metric: MetricKind
}

/// Reads the snapshot the menu bar app published. WidgetKit cannot
/// refresh every second, so the app requests reloads itself and
/// providers only schedule a slow fallback refresh.
enum SnapshotLoader {
    static let FALLBACK_REFRESH_SECONDS: TimeInterval = 15 * 60

    /// Preview data is only for the widget gallery, never for a
    /// placed widget, which must not show invented numbers.
    static func loadSnapshot(
        allows_Preview_Data: Bool
    ) -> MetricSnapshot? {
        let stored_Snapshot = try? AppGroup.makeSnapshotStore()?
            .load()
        let fallback_Snapshot =
            allows_Preview_Data ? PreviewData.SNAPSHOT : nil
        return stored_Snapshot ?? fallback_Snapshot
    }

    static func nextFallbackDate() -> Date {
        Date().addingTimeInterval(FALLBACK_REFRESH_SECONDS)
    }
}

struct SnapshotTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MetricEntry {
        MetricEntry(
            date: Date(),
            snapshot: PreviewData.SNAPSHOT,
            metric: .cpu
        )
    }

    func snapshot(
        for configuration: SelectMetricIntent,
        in context: Context
    ) async -> MetricEntry {
        MetricEntry(
            date: Date(),
            snapshot: SnapshotLoader.loadSnapshot(
                allows_Preview_Data: context.isPreview
            ),
            metric: configuration.metric
        )
    }

    func timeline(
        for configuration: SelectMetricIntent,
        in context: Context
    ) async -> Timeline<MetricEntry> {
        let entry = MetricEntry(
            date: Date(),
            snapshot: SnapshotLoader.loadSnapshot(
                allows_Preview_Data: false
            ),
            metric: configuration.metric
        )
        return Timeline(
            entries: [entry],
            policy: .after(SnapshotLoader.nextFallbackDate())
        )
    }
}
