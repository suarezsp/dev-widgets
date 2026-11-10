/// How stressed a resource is. The UI maps it to green, amber, red.
public enum LoadLevel: String, Codable, Sendable, CaseIterable {
    case normal
    case elevated
    case critical
}

/// Values at which a reading stops being `normal`: fractions for
/// shares (0.6 = 60 %), degrees for temperatures.
public struct LoadThresholds: Codable, Equatable, Sendable {
    public static let DEFAULT = LoadThresholds(
        elevated_Limit: 0.6,
        critical_Limit: 0.85
    )

    public let elevated_Limit: Double
    public let critical_Limit: Double

    public init(
        elevated_Limit: Double,
        critical_Limit: Double
    ) {
        precondition(elevated_Limit <= critical_Limit)
        self.elevated_Limit = elevated_Limit
        self.critical_Limit = critical_Limit
    }

    public func level(for value: Double) -> LoadLevel {
        if value >= critical_Limit { return .critical }
        if value >= elevated_Limit { return .elevated }
        return .normal
    }
}
