import Foundation

/// Pure parsers for the one-value files under Linux `/sys`.
public enum SysfsParser {
    public static let MILLIDEGREES_PER_DEGREE = 1_000.0

    /// "37\n" -> 0.37 (amdgpu `gpu_busy_percent`, battery capacity).
    public static func parsePercent(_ text: String) -> Double? {
        guard let percent = Double(trimmed(text)) else { return nil }
        return min(1, max(0, percent / 100))
    }

    /// "48500" -> 48.5 °C. Zones that report zero or less are
    /// placeholders without a real sensor.
    public static func parseCelsius(
        millidegree_Text: String
    ) -> Double? {
        guard let millidegrees = Double(trimmed(millidegree_Text)),
            millidegrees > 0
        else { return nil }
        return millidegrees / MILLIDEGREES_PER_DEGREE
    }

    public static func parseBattery(
        capacity_Text: String,
        status_Text: String
    ) -> BatteryState? {
        guard let charge_Fraction = parsePercent(capacity_Text) else {
            return nil
        }
        return BatteryState(
            charge_Fraction: charge_Fraction,
            power_Source: parsePowerSource(status_Text),
            minutes_Remaining: nil
        )
    }

    /// Kernel status values: Charging, Discharging, Full,
    /// Not charging, Unknown.
    static func parsePowerSource(_ status_Text: String) -> PowerSource
    {
        switch trimmed(status_Text) {
        case "Charging": .charging
        case "Full", "Not charging": .plugged
        default: .battery
        }
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
