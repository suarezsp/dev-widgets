/// An amount of a finite resource in bytes: RAM, swap or disk.
public struct Capacity: Codable, Equatable, Sendable {
    public let used_Bytes: UInt64
    public let total_Bytes: UInt64

    public init(used_Bytes: UInt64, total_Bytes: UInt64) {
        self.used_Bytes = min(used_Bytes, total_Bytes)
        self.total_Bytes = total_Bytes
    }

    public var free_Bytes: UInt64 { total_Bytes - used_Bytes }

    /// Used share in 0...1; zero when the resource has no size.
    public var used_Fraction: Double {
        guard total_Bytes > 0 else { return 0 }
        return Double(used_Bytes) / Double(total_Bytes)
    }
}
