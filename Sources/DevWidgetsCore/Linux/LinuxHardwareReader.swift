import Foundation

/// GPU, temperature and battery from Linux `/sys`. Each reading is
/// nil when the machine has no such device.
struct LinuxHardwareReader {
    let sys_Directory: URL
    /// Runs `nvidia-smi`; without one NVIDIA cards are skipped.
    var command_Runner: CommandRunner?

    func readHardware() -> HardwareStatus {
        HardwareStatus(
            gpu_Fraction: readGPUFraction(),
            thermal: readThermal(),
            battery: readBattery()
        )
    }

    func readGPUFraction() -> Double? {
        readBusyFraction() ?? readNvidiaFraction()
    }

    /// amdgpu exposes a busy percentage; NVIDIA does not.
    func readBusyFraction() -> Double? {
        devices(in: "class/drm", prefix: "card")
            .compactMap {
                KernelFiles.readText(
                    named: "device/gpu_busy_percent",
                    in: $0
                )
            }
            .compactMap(SysfsParser.parsePercent)
            .max()
    }

    func readNvidiaFraction() -> Double? {
        guard let command_Runner, hasNvidiaCard() else {
            return nil
        }
        return NvidiaSmi.readFraction(using: command_Runner)
    }

    func hasNvidiaCard() -> Bool {
        devices(in: "class/drm", prefix: "card").contains {
            let vendor_Text = KernelFiles.readText(
                named: "device/vendor",
                in: $0
            )
            return vendor_Text.map(SysfsParser.trimmed)
                == NvidiaSmi.PCI_VENDOR_ID
        }
    }

    /// The hottest zone is what decides throttling.
    func readThermal() -> ThermalReading? {
        devices(in: "class/thermal", prefix: "thermal_zone")
            .compactMap {
                KernelFiles.readText(named: "temp", in: $0)
            }
            .compactMap {
                SysfsParser.parseCelsius(millidegree_Text: $0)
            }
            .max()
            .map { ThermalReading(celsius: $0) }
    }

    func readBattery() -> BatteryState? {
        devices(in: "class/power_supply", prefix: "")
            .first(where: isBattery)
            .flatMap(readBatteryState)
    }

    func isBattery(_ supply: URL) -> Bool {
        let type_Text = KernelFiles.readText(
            named: "type",
            in: supply
        )
        return type_Text.map(SysfsParser.trimmed) == "Battery"
    }

    func readBatteryState(_ supply: URL) -> BatteryState? {
        guard
            let capacity_Text = KernelFiles.readText(
                named: "capacity",
                in: supply
            )
        else { return nil }
        let status_Text = KernelFiles.readText(
            named: "status",
            in: supply
        )
        return SysfsParser.parseBattery(
            capacity_Text: capacity_Text,
            status_Text: status_Text ?? ""
        )
    }

    private func devices(
        in relative_Path: String,
        prefix: String
    ) -> [URL] {
        let directory = sys_Directory.appendingPathComponent(
            relative_Path
        )
        return KernelFiles.listNames(in: directory)
            .filter { $0.hasPrefix(prefix) }
            .map { directory.appendingPathComponent($0) }
    }
}
