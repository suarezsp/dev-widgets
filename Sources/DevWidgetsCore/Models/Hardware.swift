/// Readings some machines simply do not have: a desktop has no
/// battery, a VM often has no GPU or temperature sensor.
public struct HardwareStatus: Codable, Equatable, Sendable {
    public static let UNKNOWN = HardwareStatus(
        gpu_Fraction: nil,
        thermal: nil,
        battery: nil
    )

    /// GPU busy share in 0...1.
    public let gpu_Fraction: Double?
    public let thermal: ThermalReading?
    public let battery: BatteryState?

    public init(
        gpu_Fraction: Double?,
        thermal: ThermalReading?,
        battery: BatteryState?
    ) {
        self.gpu_Fraction = gpu_Fraction
        self.thermal = thermal
        self.battery = battery
    }
}

/// Machine temperature. macOS only exposes a thermal state through
/// public APIs, so `celsius` is nil there.
public struct ThermalReading: Codable, Equatable, Sendable {
    public static let CELSIUS_THRESHOLDS = LoadThresholds(
        elevated_Limit: 80,
        critical_Limit: 95
    )

    public let level: LoadLevel
    public let celsius: Double?

    public init(level: LoadLevel, celsius: Double?) {
        self.level = level
        self.celsius = celsius
    }

    public init(celsius: Double) {
        level = Self.CELSIUS_THRESHOLDS.level(for: celsius)
        self.celsius = celsius
    }
}
