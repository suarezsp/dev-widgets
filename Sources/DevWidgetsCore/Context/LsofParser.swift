/// Parses `lsof -nP -iTCP -sTCP:LISTEN -Fpcn`, the macOS source of
/// listening ports. Each line starts with a field letter: p (pid),
/// c (command), f (descriptor) and n (address:port).
public enum LsofParser {
    public static let ARGUMENTS = [
        "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn",
    ]

    public static func parsePorts(
        lsof_Text: String
    ) -> [ListeningPort] {
        var process_ID: Int32?
        var process_Name = ""
        var ports: [ListeningPort] = []
        for line in lsof_Text.split(whereSeparator: \.isNewline) {
            let value = String(line.dropFirst())
            switch line.first {
            case "p": process_ID = Int32(value)
            case "c": process_Name = value
            case "n":
                let owner = process_ID.map {
                    ProcessIdentity(pid: $0, name: process_Name)
                }
                ports +=
                    parseAddress(value, owner: owner).map { [$0] }
                    ?? []
            default: continue
            }
        }
        return ports
    }

    /// "*:3000", "127.0.0.1:5432", "[::1]:8080".
    static func parseAddress(
        _ name_Text: String,
        owner: ProcessIdentity?
    ) -> ListeningPort? {
        guard let colon_Index = name_Text.lastIndex(of: ":"),
            let port = UInt16(
                name_Text[name_Text.index(after: colon_Index)...]
            )
        else { return nil }
        let host_Text = name_Text[..<colon_Index]
            .trimmingCharacters(in: ["[", "]"])
        return ListeningPort(
            port: port,
            address: host_Text,
            owner: owner
        )
    }
}
