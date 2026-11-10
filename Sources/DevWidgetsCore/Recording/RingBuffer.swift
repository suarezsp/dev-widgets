/// Fixed-size history that overwrites its oldest element when full.
public struct RingBuffer<Element: Sendable>: Sendable {
    public let capacity: Int
    private var stored_Elements: [Element] = []
    private var oldest_Index = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer needs room")
        self.capacity = capacity
        stored_Elements.reserveCapacity(capacity)
    }

    public var count: Int { stored_Elements.count }

    /// Elements from oldest to newest.
    public var ordered_Elements: [Element] {
        Array(
            stored_Elements[oldest_Index...]
                + stored_Elements[..<oldest_Index]
        )
    }

    public mutating func append(_ element: Element) {
        guard stored_Elements.count == capacity else {
            stored_Elements.append(element)
            return
        }
        stored_Elements[oldest_Index] = element
        oldest_Index = (oldest_Index + 1) % capacity
    }
}

/// Encoded as `{capacity, elements}` with elements oldest first, so
/// readers of the JSON never deal with the rotation index.
extension RingBuffer: Codable where Element: Codable {
    enum CodingKeys: String, CodingKey {
        case capacity
        case elements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let capacity = try container.decode(
            Int.self,
            forKey: .capacity
        )
        guard capacity > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .capacity,
                in: container,
                debugDescription: "RingBuffer capacity must be > 0"
            )
        }
        self.init(capacity: capacity)
        let elements = try container.decode(
            [Element].self,
            forKey: .elements
        )
        elements.suffix(capacity).forEach { append($0) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(capacity, forKey: .capacity)
        try container.encode(ordered_Elements, forKey: .elements)
    }
}

extension RingBuffer: Equatable where Element: Equatable {
    public static func == (left: Self, right: Self) -> Bool {
        left.capacity == right.capacity
            && left.ordered_Elements == right.ordered_Elements
    }
}
