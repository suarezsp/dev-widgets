import DevWidgetsCore
import Foundation

extension MetricKind {
    public static func presentGPU(
        _ gpu_Fraction: Double?
    ) -> MetricPresentation {
        guard let gpu_Fraction else { return .makeUnavailable(.gpu) }
        return presentShare(
            .gpu,
            fraction: gpu_Fraction,
            detail_Text: String(localized: "Busy")
        )
    }

    /// macOS only reports a thermal state; Linux gives degrees.
    public static func presentThermal(
        _ thermal: ThermalReading?
    ) -> MetricPresentation {
        guard let thermal else { return .makeUnavailable(.thermal) }
        let state_Text = describeThermalState(thermal.level)
        let value_Text =
            thermal.celsius.map(MetricFormatting.describeCelsius)
            ?? state_Text
        return MetricPresentation(
            kind: .thermal,
            value_Text: value_Text,
            detail_Text: thermal.celsius == nil
                ? String(localized: "Thermal state") : state_Text
        )
        .with(level: thermal.level, fraction: nil)
    }

    public static func describeThermalState(
        _ level: LoadLevel
    ) -> String {
        switch level {
        case .normal: String(localized: "Nominal")
        case .elevated: String(localized: "Warm")
        case .critical: String(localized: "Throttling")
        }
    }

    public static func presentBattery(
        _ battery: BatteryState?
    ) -> MetricPresentation {
        guard let battery else { return .makeUnavailable(.battery) }
        return MetricPresentation(
            kind: .battery,
            value_Text: MetricFormatting.describePercent(
                fraction: battery.charge_Fraction
            ),
            detail_Text: describePowerSource(battery)
        )
        .with(level: battery.level, fraction: battery.charge_Fraction)
    }

    public static func describePowerSource(
        _ battery: BatteryState
    ) -> String {
        switch battery.power_Source {
        case .charging: return String(localized: "Charging")
        case .plugged: return String(localized: "On power adapter")
        case .battery:
            guard let minutes = battery.minutes_Remaining else {
                return String(localized: "On battery")
            }
            let time_Text = MetricFormatting.describeMinutes(minutes)
            return String(localized: "\(time_Text) left")
        }
    }
}
