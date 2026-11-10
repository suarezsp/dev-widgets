import SwiftUI
import WidgetKit

@main
struct DevWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MetricWidget()
        DashboardWidget()
        DeveloperContextWidget()
        ServersWidget()
    }
}

/// Configurable widget: small features one metric, medium adds
/// three always-available metrics as compact rows.
struct MetricWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AppGroup.WIDGET_KIND,
            intent: SelectMetricIntent.self,
            provider: SnapshotTimelineProvider()
        ) { entry in
            MetricWidgetView(entry: entry)
        }
        .configurationDisplayName("System Metrics")
        .description(
            "CPU, memory, disk, network, GPU, heat or battery."
        )
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
