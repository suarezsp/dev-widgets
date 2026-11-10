/// Parses `/proc/net/dev`, summing physical interfaces only, so
/// loopback, Docker bridges and VPN tunnels are not counted twice.
public enum NetDevParser {
    public static func parseCounters(
        from text: String
    ) -> NetworkCounters? {
        let interfaces = text.split(separator: "\n")
            .compactMap(parseInterfaceLine)
        guard !interfaces.isEmpty else { return nil }
        return
            interfaces
            .filter { NetworkInterfaces.isPhysical($0.name) }
            .reduce(NetworkCounters.ZERO) { $0 + $1.counters }
    }

    /// " eth0: 1234 5 0 0 0 0 0 0 5678 ..." (rx bytes ... tx bytes).
    /// Large counters can touch the colon, so split on it first.
    static func parseInterfaceLine(
        _ line: Substring
    ) -> (name: Substring, counters: NetworkCounters)? {
        let halves = line.split(separator: ":", maxSplits: 1)
        guard halves.count == 2,
            let name = halves[0].split(separator: " ").last
        else { return nil }
        let columns = halves[1].split(separator: " ")
        guard columns.count >= 9,
            let received_Bytes = UInt64(columns[0]),
            let sent_Bytes = UInt64(columns[8])
        else { return nil }
        let counters = NetworkCounters(
            received_Bytes: received_Bytes,
            sent_Bytes: sent_Bytes
        )
        return (name, counters)
    }
}

/// Parses `/proc/diskstats`, summing whole disks only so that
/// partitions are not counted twice.
public enum DiskStatsParser {
    public static let SECTOR_BYTES: UInt64 = 512
    public static let LETTER_DISK_PREFIXES = [
        "sd", "vd", "xvd", "hd",
    ]
    public static let NUMBERED_DISK_PREFIXES = ["nvme", "mmcblk"]

    public static func parseCounters(
        from text: String
    ) -> DiskIOCounters? {
        var read_Sectors: UInt64 = 0
        var written_Sectors: UInt64 = 0
        var found_Disk = false
        for line in text.split(separator: "\n") {
            let columns = line.split(separator: " ")
            guard columns.count >= 10, isWholeDisk(columns[2]),
                let read_Count = UInt64(columns[5]),
                let written_Count = UInt64(columns[9])
            else { continue }
            read_Sectors += read_Count
            written_Sectors += written_Count
            found_Disk = true
        }
        guard found_Disk else { return nil }
        return DiskIOCounters(
            read_Bytes: read_Sectors * SECTOR_BYTES,
            written_Bytes: written_Sectors * SECTOR_BYTES
        )
    }

    /// "sda" and "nvme0n1" are disks; "sda1" and "nvme0n1p1" are not.
    static func isWholeDisk(_ name: Substring) -> Bool {
        let numbered_Prefix = NUMBERED_DISK_PREFIXES.first {
            name.hasPrefix($0)
        }
        if let numbered_Prefix {
            let suffix = name.dropFirst(numbered_Prefix.count)
            return !suffix.contains("p")
        }
        let has_Letter_Prefix = LETTER_DISK_PREFIXES.contains {
            name.hasPrefix($0)
        }
        return has_Letter_Prefix && name.last?.isLetter == true
    }
}
