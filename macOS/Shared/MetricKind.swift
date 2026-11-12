import DevWidgetsCore
import Foundation

/// The metric families a widget can feature.
public enum MetricKind: String, CaseIterable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case gpu
    case thermal
    case battery

    /// Every Mac has these, so they fill the medium widget's rows.
    public static let ALWAYS_AVAILABLE: [MetricKind] = [
        .cpu, .memory, .disk, .network,
    ]

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: String(localized: "Memory")
        case .disk: String(localized: "Disk")
        case .network: String(localized: "Network")
        case .gpu: "GPU"
        case .thermal: String(localized: "Thermal")
        case .battery: String(localized: "Battery")
        }
    }

    public var symbol_Name: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .disk: "internaldrive"
        case .network: "network"
        case .gpu: "rectangle.3.group"
        case .thermal: "thermometer.medium"
        case .battery: "battery.75percent"
        }
    }

    public func present(
        _ readings: MetricReadings
    ) -> MetricPresentation {
        switch self {
        case .cpu: Self.presentCPU(readings.cpu)
        case .memory: Self.presentMemory(readings.memory)
        case .disk: Self.presentDisk(readings.disk)
        case .network: Self.presentNetwork(readings.network)
        case .gpu: Self.presentGPU(readings.hardware.gpu_Fraction)
        case .thermal: Self.presentThermal(readings.hardware.thermal)
        case .battery: Self.presentBattery(readings.hardware.battery)
        }
    }
}
