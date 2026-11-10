/// Cumulative bytes moved by all non-loopback interfaces.
public struct NetworkCounters: Codable, Equatable, Sendable {
    public static let ZERO = NetworkCounters(
        received_Bytes: 0,
        sent_Bytes: 0
    )

    public let received_Bytes: UInt64
    public let sent_Bytes: UInt64

    public init(received_Bytes: UInt64, sent_Bytes: UInt64) {
        self.received_Bytes = received_Bytes
        self.sent_Bytes = sent_Bytes
    }

    public static func + (
        left: NetworkCounters,
        right: NetworkCounters
    ) -> NetworkCounters {
        NetworkCounters(
            received_Bytes: left.received_Bytes
                &+ right.received_Bytes,
            sent_Bytes: left.sent_Bytes &+ right.sent_Bytes
        )
    }
}

/// Network transfer speed between two samples.
public struct NetworkThroughput: Codable, Equatable, Sendable {
    public let download_Bytes_Per_Second: Double
    public let upload_Bytes_Per_Second: Double
}
