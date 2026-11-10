/// Bytes per second between two readings of a cumulative counter.
/// A counter that went backwards (reboot, 32-bit wrap) yields zero
/// instead of a bogus spike.
func bytesPerSecond(
    from previous_Bytes: UInt64,
    to current_Bytes: UInt64,
    elapsed_Seconds: Double
) -> Double {
    guard current_Bytes >= previous_Bytes,
        elapsed_Seconds > 0
    else { return 0 }
    return Double(current_Bytes - previous_Bytes) / elapsed_Seconds
}

extension NetworkThroughput {
    init(
        from previous: NetworkCounters,
        to current: NetworkCounters,
        elapsed_Seconds: Double
    ) {
        download_Bytes_Per_Second = bytesPerSecond(
            from: previous.received_Bytes,
            to: current.received_Bytes,
            elapsed_Seconds: elapsed_Seconds
        )
        upload_Bytes_Per_Second = bytesPerSecond(
            from: previous.sent_Bytes,
            to: current.sent_Bytes,
            elapsed_Seconds: elapsed_Seconds
        )
    }
}

extension DiskThroughput {
    init(
        from previous: DiskIOCounters,
        to current: DiskIOCounters,
        elapsed_Seconds: Double
    ) {
        read_Bytes_Per_Second = bytesPerSecond(
            from: previous.read_Bytes,
            to: current.read_Bytes,
            elapsed_Seconds: elapsed_Seconds
        )
        write_Bytes_Per_Second = bytesPerSecond(
            from: previous.written_Bytes,
            to: current.written_Bytes,
            elapsed_Seconds: elapsed_Seconds
        )
    }
}

extension NetworkThroughput {
    init(over interval: SampleInterval) {
        self.init(
            from: interval.old_Sample.network,
            to: interval.new_Sample.network,
            elapsed_Seconds: interval.elapsed_Seconds
        )
    }
}

extension DiskUsage {
    init(over interval: SampleInterval) {
        space = interval.new_Sample.disk.space
        guard
            let previous_Counters = interval.old_Sample.disk
                .io_Counters,
            let current_Counters = interval.new_Sample.disk
                .io_Counters
        else {
            throughput = nil
            return
        }
        throughput = DiskThroughput(
            from: previous_Counters,
            to: current_Counters,
            elapsed_Seconds: interval.elapsed_Seconds
        )
    }
}
