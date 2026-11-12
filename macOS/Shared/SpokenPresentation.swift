import DevWidgetsCore
import Foundation

/// What VoiceOver reads for the rings, bars and charts, which carry
/// their values as shapes and their level as color.
extension LoadLevel {
    /// nil while healthy: only a level that needs attention is read.
    public var spoken_Text: String? {
        switch self {
        case .normal: nil
        case .elevated: String(localized: "high")
        case .critical: String(localized: "critical")
        }
    }
}

extension MetricPresentation {
    /// "CPU, 42%, 8 cores", plus "high" or "critical" when needed.
    public var spoken_Text: String {
        guard is_Available else {
            return String(localized: "\(title), not available")
        }
        let parts = [
            title, value_Text, detail_Text, level.spoken_Text,
        ]
        return parts.compactMap { $0 }
            .joined(separator: ", ")
            .replacingOccurrences(
                of: "↓ ",
                with: String(localized: "download") + " "
            )
            .replacingOccurrences(
                of: "↑ ",
                with: String(localized: "upload") + " "
            )
    }
}

extension ServerGauge {
    /// "CPU 12%", plus the level when it needs attention.
    public var spoken_Text: String {
        [title + " " + value_Text, level.spoken_Text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

extension ServerLine {
    /// "web-1, up 3 days, CPU 12%, memory 40%, disk 71%, high".
    public var spoken_Text: String {
        ([alias, detail_Text] + gauges.map(\.spoken_Text))
            .joined(separator: ", ")
    }
}

/// A chart read as one sentence per line, lowest and highest value.
public enum HistorySummary {
    /// "CPU: lowest 3%, highest 80%"; nil without samples. Shares
    /// are fractions, other series bytes per second.
    public static func describe(
        name: String,
        values: [Double],
        is_Share: Bool
    ) -> String? {
        guard let lowest = values.min(), let highest = values.max()
        else { return nil }
        let lowest_Text = describeValue(lowest, is_Share: is_Share)
        let highest_Text = describeValue(highest, is_Share: is_Share)
        return String(
            localized: """
                \(name): lowest \(lowest_Text), \
                highest \(highest_Text)
                """
        )
    }

    static func describeValue(
        _ value: Double,
        is_Share: Bool
    ) -> String {
        is_Share
            ? MetricFormatting.describePercent(fraction: value)
            : MetricFormatting.describeRate(bytes_Per_Second: value)
    }
}
