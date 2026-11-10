#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// The lines of an `ssh_config(5)` file DevWidgets reads: "Host"
/// names worth suggesting and "Include" patterns.
public enum SSHConfigParser {
    static let PATTERN_CHARACTERS = CharacterSet(charactersIn: "*?!")

    /// Every "Host" name that is not a pattern, in file order.
    public static func listAliases(config_Text: String) -> [String] {
        var aliases: [String] = []
        for line in config_Text.split(separator: "\n") {
            for alias in parseHostLine(line)
            where !aliases.contains(alias) {
                aliases.append(alias)
            }
        }
        return aliases
    }

    /// "Host web-1 web-2", "host=db", "  Host *": keyword case and
    /// "=" are both allowed by ssh_config(5).
    static func parseHostLine(_ line: Substring) -> [String] {
        parseArguments(line, keyword: "host").filter {
            $0.rangeOfCharacter(from: PATTERN_CHARACTERS) == nil
                && RemoteHost(alias: $0) != nil
        }
    }

    /// "Include conf.d/* ~/.ssh/work" gives both patterns.
    static func parseIncludeLine(_ line: Substring) -> [String] {
        parseArguments(line, keyword: "include")
    }

    static func parseArguments(
        _ line: Substring,
        keyword: String
    ) -> [String] {
        let words = line.split {
            $0 == " " || $0 == "\t" || $0 == "="
        }
        guard let first_Word = words.first,
            first_Word.lowercased() == keyword
        else { return [] }
        return words.dropFirst().map(String.init)
    }
}

/// Reads `~/.ssh/config` and, like `ssh`, the files it includes:
/// relative paths start in `~/.ssh`, "~" is the home folder and
/// globs expand. An include inside a "Host" block counts too: a
/// suggestion is harmless. Nesting stops at ssh's own limit.
public struct SSHConfigReader: Sendable {
    /// ssh's READCONF_MAX_DEPTH.
    public static let MAX_INCLUDE_DEPTH = 16

    public let home_Directory: URL

    public init(
        home_Directory: URL = FileManager.default
            .homeDirectoryForCurrentUser
    ) {
        self.home_Directory = home_Directory
    }

    var ssh_Directory: URL {
        home_Directory.appendingPathComponent(".ssh")
    }

    public func listAliases() -> [String] {
        var walk = IncludeWalk(reader: self)
        walk.collect(
            from: ssh_Directory.appendingPathComponent("config"),
            depth: 0
        )
        return walk.aliases
    }

    /// "conf.d/*" → the matching files in `~/.ssh/conf.d`, sorted.
    func expandInclude(_ pattern: String) -> [URL] {
        let full_Pattern: String
        if pattern.hasPrefix("~/") {
            full_Pattern =
                home_Directory.path + "/" + pattern.dropFirst(2)
        } else if pattern.hasPrefix("/") {
            full_Pattern = pattern
        } else {
            full_Pattern = ssh_Directory.path + "/" + pattern
        }
        return Self.matchFiles(full_Pattern).map {
            URL(fileURLWithPath: $0)
        }
    }

    static func matchFiles(_ pattern: String) -> [String] {
        var matches = glob_t()
        defer { globfree(&matches) }
        guard glob(pattern, 0, nil, &matches) == 0 else { return [] }
        return (0..<Int(matches.gl_pathc)).compactMap { index in
            matches.gl_pathv[index].map { String(cString: $0) }
        }
    }
}

/// One pass over a config and its includes. Each file is read at
/// most once, so an include loop ends.
private struct IncludeWalk {
    let reader: SSHConfigReader
    var aliases: [String] = []
    var visited_Paths: Set<String> = []

    mutating func collect(from file_URL: URL, depth: Int) {
        guard depth <= SSHConfigReader.MAX_INCLUDE_DEPTH,
            visited_Paths.insert(file_URL.path).inserted,
            let config_Text = try? String(
                contentsOf: file_URL,
                encoding: .utf8
            )
        else { return }
        for line in config_Text.split(separator: "\n") {
            let names = SSHConfigParser.parseHostLine(line)
            aliases += names.filter { !aliases.contains($0) }
            let included_URLs = SSHConfigParser.parseIncludeLine(line)
                .flatMap(reader.expandInclude)
            for included_URL in included_URLs {
                collect(from: included_URL, depth: depth + 1)
            }
        }
    }
}
