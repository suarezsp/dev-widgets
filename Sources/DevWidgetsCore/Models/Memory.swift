/// Physical memory, swap and the kernel's memory pressure.
public struct MemoryUsage: Codable, Equatable, Sendable {
    public let physical: Capacity
    public let swap: Capacity
    public let pressure: LoadLevel

    public init(
        physical: Capacity,
        swap: Capacity,
        pressure: LoadLevel
    ) {
        self.physical = physical
        self.swap = swap
        self.pressure = pressure
    }
}
