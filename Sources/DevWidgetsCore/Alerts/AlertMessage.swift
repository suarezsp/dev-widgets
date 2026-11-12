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
        let name = Self.describeName(metric)
        let value_Text = Self.describeValue(alert.value, of: metric)
        title = String(localized: "\(name) at \(value_Text)")
        let limit_Text = Self.describeValue(
            alert.rule.limit,
            of: metric
        )
        let seconds = Int(settings.sustain_Seconds)
        body =
            metric.alerts_Below_Limit
            ? String(
                localized: """
                    Under your \(limit_Text) limit for at least \
                    \(seconds) s.
                    """
            )
            : String(
                localized: """
                    Over your \(limit_Text) limit for at least \
                    \(seconds) s.
                    """
            )
    }

    public static func describeName(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: "CPU"
        case .memory: String(localized: "Memory")
        case .disk_Space: String(localized: "Disk space")
        case .temperature: String(localized: "Temperature")
        case .battery: String(localized: "Battery")
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
