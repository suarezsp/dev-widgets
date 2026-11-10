/// Title and body of a threshold notification, e.g. "CPU at 94%"
/// / "Over your 90% limit for at least 30 s."
public struct AlertMessage: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    public init(alert: ThresholdAlert, settings: AlertSettings) {
        let metric = alert.rule.metric
        title =
            "\(Self.describeName(metric)) at "
            + Self.describeValue(alert.value, of: metric)
        let direction = metric.alerts_Below_Limit ? "Under" : "Over"
        let limit_Text = Self.describeValue(
            alert.rule.limit,
            of: metric
        )
        let seconds_Text = Int(settings.sustain_Seconds)
        body =
            "\(direction) your \(limit_Text) limit for at least"
            + " \(seconds_Text) s."
    }

    public static func describeName(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .disk_Space: "Disk space"
        case .temperature: "Temperature"
        case .battery: "Battery"
        }
    }

    public static func describeValue(
        _ value: Double,
        of metric: AlertMetric
    ) -> String {
        metric == .temperature
            ? MetricFormatting.describeCelsius(value)
            : MetricFormatting.describePercent(fraction: value)
    }
}
