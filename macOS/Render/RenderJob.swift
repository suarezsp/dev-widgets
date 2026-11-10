import DevWidgetsCore
import SwiftUI
import WidgetKit

/// One widget at one size, filled with the preview data the widget
/// gallery shows.
struct RenderJob {
    let file_Name: String
    let family: WidgetFamily
    let content: AnyView

    static func makeAll() -> [RenderJob] {
        makeMetricJobs() + [
            dashboard(.systemLarge, file_Name: "dashboard-large"),
            dashboard(
                .systemExtraLarge,
                file_Name: "dashboard-extra-large"
            ),
            context(.systemMedium, file_Name: "context-medium"),
            context(.systemLarge, file_Name: "context-large"),
            servers(.systemMedium, file_Name: "servers-medium"),
            servers(.systemLarge, file_Name: "servers-large"),
        ]
    }

    static func makeMetricJobs() -> [RenderJob] {
        [
            metric(
                .cpu,
                family: .systemSmall,
                file_Name: "small-cpu"
            ),
            metric(
                .network,
                family: .systemSmall,
                file_Name: "small-network"
            ),
            metric(
                .memory,
                family: .systemMedium,
                file_Name: "medium-memory"
            ),
        ]
    }

    static func metric(
        _ kind: MetricKind,
        family: WidgetFamily,
        file_Name: String
    ) -> RenderJob {
        let entry = MetricEntry(
            date: Date(),
            snapshot: PreviewData.SNAPSHOT,
            metric: kind
        )
        return RenderJob(
            file_Name: file_Name,
            family: family,
            content: AnyView(MetricWidgetView(entry: entry))
        )
    }
}

extension RenderJob {
    static func dashboard(
        _ family: WidgetFamily,
        file_Name: String
    ) -> RenderJob {
        let view = DashboardWidgetView(
            snapshot: PreviewData.SNAPSHOT,
            armed_Action: nil
        )
        return RenderJob(
            file_Name: file_Name,
            family: family,
            content: AnyView(view)
        )
    }

    static func context(
        _ family: WidgetFamily,
        file_Name: String
    ) -> RenderJob {
        let view = DeveloperContextWidgetView(
            context: PreviewData.CONTEXT,
            armed_Action: nil
        )
        return RenderJob(
            file_Name: file_Name,
            family: family,
            content: AnyView(view)
        )
    }

    static func servers(
        _ family: WidgetFamily,
        file_Name: String
    ) -> RenderJob {
        RenderJob(
            file_Name: file_Name,
            family: family,
            content: AnyView(
                ServersWidgetView(overview: PreviewData.SERVERS)
            )
        )
    }
}
