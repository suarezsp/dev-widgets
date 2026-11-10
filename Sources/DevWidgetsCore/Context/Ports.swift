/// A TCP port some program is listening on, e.g. a dev server.
public struct ListeningPort: Codable, Equatable, Sendable {
    public static let ANY_ADDRESS = "*"

    public let port: UInt16
    /// "*" for every interface, else e.g. "127.0.0.1" or "::1".
    public let address: String
    /// nil when the socket belongs to another user's process.
    public let owner: ProcessIdentity?

    public init(
        port: UInt16,
        address: String,
        owner: ProcessIdentity?
    ) {
        self.port = port
        self.address = address
        self.owner = owner
    }

    public var is_Local_Only: Bool {
        address.hasPrefix("127.") || address == "::1"
    }
}

public enum PortList {
    /// One row per port and owner, sorted by port. A server bound
    /// to both IPv4 and IPv6 appears once, preferring "*".
    public static func merge(
        _ ports: [ListeningPort]
    ) -> [ListeningPort] {
        var merged_Ports: [ListeningPort] = []
        for candidate in ports.sorted(by: isListedFirst) {
            let is_Duplicate = merged_Ports.contains {
                $0.port == candidate.port
                    && $0.owner == candidate.owner
            }
            if !is_Duplicate { merged_Ports.append(candidate) }
        }
        return merged_Ports
    }

    static func isListedFirst(
        _ left: ListeningPort,
        _ right: ListeningPort
    ) -> Bool {
        if left.port != right.port { return left.port < right.port }
        return left.address == ListeningPort.ANY_ADDRESS
            && right.address != ListeningPort.ANY_ADDRESS
    }
}
