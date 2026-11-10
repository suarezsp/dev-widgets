import Foundation

/// The readings a user can be alerted about.
public enum AlertMetric: String, Codable, CaseIterable, Sendable {
    case cpu
    case memory
    case disk_Space
    case temperature
    case battery

    /// Battery alerts when the charge falls below the limit; the
    /// others when the reading rises above it.
    public var alerts_Below_Limit: Bool { self == .battery }

    /// How far back past the limit a reading must go before the
    /// alert can fire again: fractions, or degrees for heat.
    public var rearm_Margin: Double {
        self == .temperature ? 5 : 0.05
    }

    /// nil when this Mac cannot measure it, or the battery is not
    /// in use: a plugged-in laptop never alerts on charge.
    public func measure(_ readings: MetricReadings) -> Double? {
        switch self {
        case .cpu: readings.cpu.total_Fraction
        case .memory: readings.memory.physical.used_Fraction
        case .disk_Space: readings.disk.space.used_Fraction
        case .temperature: readings.hardware.thermal?.celsius
        case .battery: Self.measureBattery(readings.hardware.battery)
        }
    }

    /// The limits the settings let the user choose from.
    public var limit_Range: ClosedRange<Double> {
        switch self {
        case .temperature: 60...110
        case .battery: 0.05...0.5
        default: 0.5...0.99
        }
    }

    /// One degree, or one percentage point.
    public var limit_Step: Double { self == .temperature ? 1 : 0.01 }

    static func measureBattery(_ battery: BatteryState?) -> Double? {
        guard let battery, battery.power_Source == .battery else {
            return nil
        }
        return battery.charge_Fraction
    }
}

public struct AlertRule: Codable, Equatable, Sendable {
    public let metric: AlertMetric
    public var limit: Double
    public var is_Enabled: Bool

    public init(metric: AlertMetric, limit: Double, is_Enabled: Bool)
    {
        self.metric = metric
        self.limit = limit
        self.is_Enabled = is_Enabled
    }

    public func isBreached(by value: Double) -> Bool {
        metric.alerts_Below_Limit ? value <= limit : value >= limit
    }

    public func isRecovered(by value: Double) -> Bool {
        let margin = metric.rearm_Margin
        return metric.alerts_Below_Limit
            ? value > limit + margin : value < limit - margin
    }
}

/// Everything the user can tune, saved as JSON in user defaults.
/// Three guards against spam: a reading must stay past its limit
/// for `sustain_Seconds`, must recover before alerting again, and
/// one metric alerts at most once per `cooldown_Seconds`.
public struct AlertSettings: Codable, Equatable, Sendable {
    public static let DEFAULT = AlertSettings(
        rules: [
            AlertRule(metric: .cpu, limit: 0.9, is_Enabled: true),
            AlertRule(metric: .memory, limit: 0.9, is_Enabled: true),
            AlertRule(
                metric: .disk_Space,
                limit: 0.9,
                is_Enabled: true
            ),
            AlertRule(
                metric: .temperature,
                limit: 95,
                is_Enabled: true
            ),
            AlertRule(metric: .battery, limit: 0.1, is_Enabled: true),
        ]
    )

    public var rules: [AlertRule]
    public var sustain_Seconds = 30.0
    public var cooldown_Seconds = 900.0
    /// Notify when the chosen project's branch CI fails.
    public var notifies_CI_Failure = true
    /// Notify when a monitored server stops answering.
    public var notifies_Server_Down = true

    public init(rules: [AlertRule]) {
        self.rules = rules
    }

    public var timing: AlertTiming {
        AlertTiming(
            sustain_Seconds: sustain_Seconds,
            cooldown_Seconds: cooldown_Seconds
        )
    }

    enum CodingKeys: String, CodingKey {
        case rules
        case sustain_Seconds
        case cooldown_Seconds
        case notifies_CI_Failure
        case notifies_Server_Down
    }

    /// Settings saved by an older version lack newer keys; those
    /// take their defaults instead of discarding the user's limits.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        rules = try container.decode([AlertRule].self, forKey: .rules)
        let defaults = AlertSettings(rules: [])
        sustain_Seconds = try container.decode(
            .sustain_Seconds,
            or: defaults.sustain_Seconds
        )
        cooldown_Seconds = try container.decode(
            .cooldown_Seconds,
            or: defaults.cooldown_Seconds
        )
        notifies_CI_Failure = try container.decode(
            .notifies_CI_Failure,
            or: defaults.notifies_CI_Failure
        )
        notifies_Server_Down = try container.decode(
            .notifies_Server_Down,
            or: defaults.notifies_Server_Down
        )
    }

    public func rule(for metric: AlertMetric) -> AlertRule? {
        rules.first { $0.metric == metric }
    }
}

extension KeyedDecodingContainer {
    /// The value under `key`, or `fallback` when the key is absent.
    func decode<Value: Decodable>(
        _ key: Key,
        or fallback: Value
    ) throws -> Value {
        try decodeIfPresent(Value.self, forKey: key) ?? fallback
    }
}
