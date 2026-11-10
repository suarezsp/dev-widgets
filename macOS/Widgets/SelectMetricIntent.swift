import AppIntents
import WidgetKit

/// Lets the user pick, per widget, which metric is featured.
struct SelectMetricIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Metric" }
    static var description: IntentDescription {
        IntentDescription("Pick the metric this widget features.")
    }

    @Parameter(title: "Metric", default: .cpu)
    var metric: MetricKind

    init() {}

    init(metric: MetricKind) {
        self.metric = metric
    }
}

extension MetricKind: AppEnum {
    public typealias TypeLabel = TypeDisplayRepresentation

    public static var typeDisplayRepresentation: TypeLabel {
        "Metric"
    }

    public typealias CaseLabels = [MetricKind: DisplayRepresentation]

    public static var caseDisplayRepresentations: CaseLabels {
        [
            .cpu: "CPU",
            .memory: "Memory",
            .disk: "Disk",
            .network: "Network",
            .gpu: "GPU",
            .thermal: "Thermal",
            .battery: "Battery",
        ]
    }
}
