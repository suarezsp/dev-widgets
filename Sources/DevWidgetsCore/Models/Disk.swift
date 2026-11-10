/// Cumulative bytes moved by the block devices since boot.
public struct DiskIOCounters: Codable, Equatable, Sendable {
    public let read_Bytes: UInt64
    public let written_Bytes: UInt64

    public init(read_Bytes: UInt64, written_Bytes: UInt64) {
        self.read_Bytes = read_Bytes
        self.written_Bytes = written_Bytes
    }
}

/// Raw disk state: volume space plus I/O counters when available.
public struct DiskSample: Codable, Equatable, Sendable {
    public let space: Capacity
    public let io_Counters: DiskIOCounters?

    public init(space: Capacity, io_Counters: DiskIOCounters?) {
        self.space = space
        self.io_Counters = io_Counters
    }
}

/// Disk transfer speed between two samples.
public struct DiskThroughput: Codable, Equatable, Sendable {
    public let read_Bytes_Per_Second: Double
    public let write_Bytes_Per_Second: Double
}

/// Disk state shown to the user.
public struct DiskUsage: Codable, Equatable, Sendable {
    public let space: Capacity
    public let throughput: DiskThroughput?
}
