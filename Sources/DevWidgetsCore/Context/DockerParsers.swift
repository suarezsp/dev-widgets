import Foundation

/// Parses `docker ps` and `docker stats` run with
/// `--format '{{json .}}'`: one JSON object per line, every value
/// a string ("0.15%", "12.3MiB / 7.6GiB").
public enum DockerParser {
    public static let JSON_FORMAT = "{{json .}}"

    public static func parseContainers(
        ps_Text: String
    ) -> [ContainerUsage] {
        decodeLines(ps_Text, as: DockerPsLine.self).map { line in
            let identity = ContainerIdentity(
                container_ID: line.container_ID,
                name: line.names,
                image: line.image
            )
            return ContainerUsage(
                identity: identity,
                state: line.state
            )
        }
    }

    /// Adds CPU and memory to the containers `stats` listed.
    /// `stats` may print a shorter ID than `ps`.
    public static func addUsage(
        stats_Text: String,
        to containers: [ContainerUsage]
    ) -> [ContainerUsage] {
        let stats_Lines = decodeLines(
            stats_Text,
            as: DockerStatsLine.self
        )
        return containers.map { container in
            let container_ID = container.identity.container_ID
            let stats_Line = stats_Lines.first {
                container_ID.hasPrefix($0.container_ID)
                    || $0.container_ID.hasPrefix(container_ID)
            }
            return stats_Line.map { measure(container, $0) }
                ?? container
        }
    }

    static func measure(
        _ container: ContainerUsage,
        _ stats_Line: DockerStatsLine
    ) -> ContainerUsage {
        var measured = container
        measured.cpu_Fraction = UnitTextParser.parsePercent(
            stats_Line.cpu_Percent_Text
        )
        let used_Text =
            stats_Line.memory_Usage_Text
            .split(separator: "/").first ?? ""
        measured.memory_Bytes = UnitTextParser.parseSize(used_Text)
        return measured
    }

    static func decodeLines<Line: Decodable>(
        _ text: String,
        as line_Type: Line.Type
    ) -> [Line] {
        let decoder = JSONDecoder()
        return text.split(whereSeparator: \.isNewline).compactMap {
            try? decoder.decode(line_Type, from: Data($0.utf8))
        }
    }
}

/// One line of `docker ps --format '{{json .}}'`.
struct DockerPsLine: Decodable {
    let container_ID: String
    let names: String
    let image: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case container_ID = "ID"
        case names = "Names"
        case image = "Image"
        case state = "State"
    }
}

/// One line of `docker stats --format '{{json .}}'`.
struct DockerStatsLine: Decodable {
    let container_ID: String
    let cpu_Percent_Text: String
    let memory_Usage_Text: String

    enum CodingKeys: String, CodingKey {
        case container_ID = "ID"
        case cpu_Percent_Text = "CPUPerc"
        case memory_Usage_Text = "MemUsage"
    }
}

/// Human-readable numbers as Docker prints them.
public enum UnitTextParser {
    /// Decimal (kB, MB) and binary (KiB, MiB) units both appear.
    static let UNIT_FACTORS: [String: Double] = [
        "B": 1, "kB": 1e3, "KB": 1e3, "MB": 1e6, "GB": 1e9,
        "TB": 1e12,
        "KiB": 1_024, "MiB": 1_048_576, "GiB": 1_073_741_824,
        "TiB": 1_099_511_627_776,
    ]

    /// "12.5%" -> 0.125; "--" (container starting) -> nil.
    public static func parsePercent<Text: StringProtocol>(
        _ text: Text
    ) -> Double? {
        let number_Text = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "%", with: "")
        return Double(number_Text).map { $0 / 100 }
    }

    /// "12.3MiB" -> 12_897_484; "0B" -> 0.
    public static func parseSize<Text: StringProtocol>(
        _ text: Text
    ) -> UInt64? {
        let size_Text = text.trimmingCharacters(in: .whitespaces)
        guard
            let unit_Start = size_Text.firstIndex(where: \.isLetter),
            let number = Double(size_Text[..<unit_Start]),
            let factor = UNIT_FACTORS[
                String(size_Text[unit_Start...])
            ]
        else { return nil }
        return UInt64((number * factor).rounded())
    }
}
