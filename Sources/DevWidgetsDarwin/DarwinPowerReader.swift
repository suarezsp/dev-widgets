#if os(macOS)
import DevWidgetsCore
import Foundation
import IOKit.ps

/// Battery from IOKit power sources and the thermal state from
/// `ProcessInfo`. macOS has no public temperature API, so the
/// reading carries a level but no degrees.
enum DarwinPowerReader {
    /// Keys and values from IOKit/ps/IOPSKeys.h.
    static let TYPE_KEY = "Type"
    static let INTERNAL_BATTERY_TYPE = "InternalBattery"
    static let CURRENT_CAPACITY_KEY = "Current Capacity"
    static let MAX_CAPACITY_KEY = "Max Capacity"
    static let IS_CHARGING_KEY = "Is Charging"
    static let SOURCE_STATE_KEY = "Power Source State"
    static let AC_POWER_VALUE = "AC Power"
    static let TIME_TO_EMPTY_KEY = "Time to Empty"

    static func readThermal() -> ThermalReading {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: ThermalReading(level: .normal, celsius: nil)
        case .fair: ThermalReading(level: .elevated, celsius: nil)
        default: ThermalReading(level: .critical, celsius: nil)
        }
    }

    static func readBattery() -> BatteryState? {
        guard
            let info = IOPSCopyPowerSourcesInfo()?
                .takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?
                .takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        return sources.lazy
            .compactMap { describe(source: $0, in: info) }
            .first {
                $0[TYPE_KEY] as? String == INTERNAL_BATTERY_TYPE
            }
            .flatMap(parseBattery)
    }

    static func describe(
        source: CFTypeRef,
        in info: CFTypeRef
    ) -> [String: Any]? {
        IOPSGetPowerSourceDescription(info, source)?
            .takeUnretainedValue() as? [String: Any]
    }

    static func parseBattery(
        _ description: [String: Any]
    ) -> BatteryState? {
        guard
            let current = description[CURRENT_CAPACITY_KEY]
                as? Double,
            let maximum = description[MAX_CAPACITY_KEY] as? Double,
            maximum > 0
        else { return nil }
        let minutes = description[TIME_TO_EMPTY_KEY] as? Int
        return BatteryState(
            charge_Fraction: current / maximum,
            power_Source: parsePowerSource(description),
            minutes_Remaining: minutes.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    static func parsePowerSource(
        _ description: [String: Any]
    ) -> PowerSource {
        if description[IS_CHARGING_KEY] as? Bool == true {
            return .charging
        }
        let state = description[SOURCE_STATE_KEY] as? String
        return state == AC_POWER_VALUE ? .plugged : .battery
    }
}
#endif
