import Foundation

/// Short, locale-neutral labels for bytes, rates, percentages,
/// temperatures and durations. Bytes use binary units, like
/// Activity Monitor.
public enum MetricFormatting {
    public static let UNIT_NAMES = [
        "B", "KB", "MB", "GB", "TB", "PB",
    ]
    public static let UNIT_STEP = 1024.0

    /// 1536 -> "1.5 KB", 52_428_800 -> "50 MB".
    public static func describe(bytes: Double) -> String {
        var scaled_Value = max(0, bytes)
        var unit_Index = 0
        let last_Unit_Index = UNIT_NAMES.count - 1
        while scaled_Value >= UNIT_STEP, unit_Index < last_Unit_Index
        {
            scaled_Value /= UNIT_STEP
            unit_Index += 1
        }
        let number_Text =
            unit_Index == 0
            ? String(Int(scaled_Value))
            : formatScaled(scaled_Value)
        return "\(number_Text) \(UNIT_NAMES[unit_Index])"
    }

    public static func describeRate(
        bytes_Per_Second: Double
    ) -> String {
        describe(bytes: bytes_Per_Second) + "/s"
    }

    /// 0.423 -> "42%"; values are clamped to 0...100 %.
    public static func describePercent(fraction: Double) -> String {
        let clamped_Fraction = min(1, max(0, fraction))
        return "\(Int((clamped_Fraction * 100).rounded()))%"
    }

    /// One decimal below 10 ("9.8"), whole numbers above ("12").
    static func formatScaled(_ value: Double) -> String {
        guard value < 10 else { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }

    /// Process CPU where 1.0 is one core, so 1.52 -> "152%".
    public static func describeCoreShare(_ fraction: Double) -> String
    {
        "\(Int((max(0, fraction) * 100).rounded()))%"
    }

    /// 72.4 -> "72 °C".
    public static func describeCelsius(_ celsius: Double) -> String {
        "\(Int(celsius.rounded())) °C"
    }

    /// 45 -> "45 min", 125 -> "2 h 05 min".
    public static func describeMinutes(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(max(0, minutes)) min" }
        let minute_Text = String(format: "%02d", minutes % 60)
        return "\(minutes / 60) h \(minute_Text) min"
    }
}
