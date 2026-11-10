import Testing
@testable import DevWidgetsCore

struct HardwareTests {
    @Test func thermalLevelFollowsCelsiusThresholds() {
        #expect(ThermalReading(celsius: 60).level == .normal)
        #expect(ThermalReading(celsius: 85).level == .elevated)
        #expect(ThermalReading(celsius: 99).level == .critical)
    }

    @Test func lowBatteryIsOnlyAWorryOnBattery() {
        let low_Battery = BatteryState(
            charge_Fraction: 0.08,
            power_Source: .battery,
            minutes_Remaining: 20
        )
        let low_Charging = BatteryState(
            charge_Fraction: 0.08,
            power_Source: .charging,
            minutes_Remaining: nil
        )
        #expect(low_Battery.level == .critical)
        #expect(low_Charging.level == .normal)
    }

    @Test func batteryChargeIsClamped() {
        let battery = BatteryState(
            charge_Fraction: 1.4,
            power_Source: .plugged,
            minutes_Remaining: nil
        )
        #expect(battery.charge_Fraction == 1)
    }

    @Test func sysfsValuesAreParsed() {
        #expect(SysfsParser.parsePercent("37\n") == 0.37)
        #expect(SysfsParser.parsePercent("n/a") == nil)
        let celsius = SysfsParser.parseCelsius(
            millidegree_Text: "48500\n"
        )
        #expect(celsius == 48.5)
        #expect(
            SysfsParser.parseCelsius(millidegree_Text: "0") == nil
        )
    }

    @Test func kernelBatteryStatusMapsToPowerSource() {
        #expect(SysfsParser.parsePowerSource("Charging") == .charging)
        #expect(SysfsParser.parsePowerSource("Full\n") == .plugged)
        #expect(
            SysfsParser.parsePowerSource("Not charging") == .plugged
        )
        #expect(
            SysfsParser.parsePowerSource("Discharging") == .battery
        )
    }

    @Test func fixtureTreeGivesEveryHardwareReading() {
        let hardware_Reader = LinuxHardwareReader(
            sys_Directory: Fixtures.SYS_DIRECTORY
        )
        let hardware = hardware_Reader.readHardware()
        #expect(hardware.gpu_Fraction == 0.37)
        #expect(hardware.thermal?.celsius == 83)
        #expect(hardware.thermal?.level == .elevated)
        #expect(hardware.battery?.charge_Fraction == 0.18)
        #expect(hardware.battery?.level == .elevated)
    }

    @Test func missingSysTreeMeansUnknownHardware() {
        let hardware_Reader = LinuxHardwareReader(
            sys_Directory: Fixtures.ROOT_DIRECTORY
                .appendingPathComponent("missing")
        )
        #expect(hardware_Reader.readHardware() == .UNKNOWN)
    }
}
