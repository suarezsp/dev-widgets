import Foundation

/// The one command a poll runs on the server, and the parser of
/// its answer. `exec sh -c` makes it work whatever the login shell
/// (bash, zsh, fish, tcsh); it only reads files and runs `df` and
/// `uname`, so it needs no privileges and changes nothing.
public enum RemoteProbe {
    static let MARKER = "@@devwidgets "
    static let PROC_FILES = [
        "stat", "meminfo", "loadavg", "uptime",
        "net/dev",
    ]

    /// `disk_Path` was checked by `RemoteHost`: plain path
    /// characters only, so it cannot break out of the quotes.
    public static func makeScript(disk_Path: String) -> String {
        "exec sh -c 'LC_ALL=C; export LC_ALL;"
            + " for f in \(PROC_FILES.joined(separator: " ")); do"
            + " echo \"\(MARKER)$f\"; cat /proc/$f; done;"
            + " echo \"\(MARKER)df\"; df -kP \(disk_Path);"
            + " echo \"\(MARKER)uname\"; uname -snr'"
    }

    /// Splits the answer into its sections, keyed by name.
    static func splitSections(_ output: String) -> [String: String] {
        var sections: [String: String] = [:]
        var section_Name: String?
        for line in output.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            if line.hasPrefix(MARKER) {
                section_Name = String(line.dropFirst(MARKER.count))
                sections[section_Name ?? ""] = ""
            } else if let section_Name {
                sections[section_Name, default: ""] += line + "\n"
            }
        }
        return sections
    }

    public static func parseSnapshot(
        _ output: String
    ) throws(RemoteProblem) -> RemoteSnapshot {
        let sections = splitSections(output)
        let system_Text = (sections["uname"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let cpu = ProcStatParser.parseCPUSample(
                from: sections["stat"] ?? ""
            ),
            let memory = MemInfoParser.parseMemory(
                meminfo_Text: sections["meminfo"] ?? "",
                pressure_Level: nil
            )
        else { throw .not_Linux(system: describeSystem(system_Text)) }
        var snapshot = RemoteSnapshot(
            cpu: cpu,
            memory: memory,
            disk_Space: parseDiskSpace(sections["df"] ?? "")
        )
        fillDetails(&snapshot, sections: sections)
        snapshot.system_Text = system_Text
        return snapshot
    }

    static func fillDetails(
        _ snapshot: inout RemoteSnapshot,
        sections: [String: String]
    ) {
        snapshot.network =
            NetDevParser.parseCounters(
                from: sections["net/dev"] ?? ""
            )
            ?? .ZERO
        snapshot.load_Average = parseLoadAverage(
            sections["loadavg"] ?? ""
        )
        snapshot.uptime_Seconds = (sections["uptime"] ?? "")
            .split(separator: " ").first.flatMap { Double($0) }
    }

    /// "Darwin mac.local 24.1.0" names the system; empty means the
    /// shell printed nothing we know.
    static func describeSystem(_ system_Text: String) -> String {
        system_Text.split(separator: " ").first.map(String.init)
            ?? "Unknown system"
    }

    /// "0.42 0.37 0.30 2/638 24833".
    static func parseLoadAverage(_ text: String) -> LoadAverage? {
        let values = text.split(separator: " ").prefix(3)
            .compactMap { Double($0) }
        guard values.count == 3 else { return nil }
        return LoadAverage(
            one_Minute: values[0],
            five_Minutes: values[1],
            fifteen_Minutes: values[2]
        )
    }

    /// POSIX `df -kP`: the second line holds size, used and
    /// available in KiB. Used is size minus available, as locally
    /// with `statvfs`, so blocks reserved for root count as used.
    static func parseDiskSpace(_ df_Text: String) -> Capacity {
        let lines = df_Text.split(separator: "\n")
        let columns =
            lines.count > 1
            ? lines[1].split(separator: " ") : []
        guard columns.count >= 4,
            let total_Kibibytes = UInt64(columns[1]),
            let available_Kibibytes = UInt64(columns[3])
        else { return Capacity(used_Bytes: 0, total_Bytes: 0) }
        return MemInfoParser.capacityFromAvailable(
            available_Kibibytes * MemInfoParser.BYTES_PER_KIBIBYTE,
            total_Bytes: total_Kibibytes
                * MemInfoParser.BYTES_PER_KIBIBYTE
        )
    }
}
