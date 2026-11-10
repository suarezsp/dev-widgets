public enum PowerSource: String, Codable, Sendable {
    case battery
    case charging
    /// On AC power and not charging (full or charge limit reached).
    case plugged
}

public struct BatteryState: Codable, Equatable, Sendable {
    /// Level is graded on the missing charge: ≤ 20 % left is amber,
    /// ≤ 10 % left is red. On AC power the battery is never a worry.
    public static let MISSING_CHARGE_THRESHOLDS = LoadThresholds(
        elevated_Limit: 0.8,
        critical_Limit: 0.9
    )

    public let charge_Fraction: Double
    public let power_Source: PowerSource
    public let minutes_Remaining: Int?

    public init(
        charge_Fraction: Double,
        power_Source: PowerSource,
        minutes_Remaining: Int?
    ) {
        self.charge_Fraction = min(1, max(0, charge_Fraction))
        self.power_Source = power_Source
        self.minutes_Remaining = minutes_Remaining
    }

    public var level: LoadLevel {
        guard power_Source == .battery else { return .normal }
        return Self.MISSING_CHARGE_THRESHOLDS.level(
            for: 1 - charge_Fraction
        )
    }
}
