import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Picks the layout for the widget family and applies the glass
/// container background shared by every size.
struct MetricWidgetView: View {
    @LayoutFamily private var widget_Family

    let entry: MetricEntry

    var body: some View {
        content
            .systemWidgetBackground()
    }

    @ViewBuilder
    private var content: some View {
        if let readings = entry.snapshot?.readings {
            let featured = entry.metric.present(readings)
            switch widget_Family {
            case .systemMedium:
                MediumMetricView(
                    featured: featured,
                    others: otherPresentations(readings)
                )
            default:
                SmallMetricView(presentation: featured)
            }
        } else {
            WaitingForDataView()
        }
    }

    static let COMPANION_COUNT = 3

    private func otherPresentations(
        _ readings: MetricReadings
    ) -> [MetricPresentation] {
        MetricKind.ALWAYS_AVAILABLE
            .filter { $0 != entry.metric }
            .prefix(Self.COMPANION_COUNT)
            .map { $0.present(readings) }
    }
}
