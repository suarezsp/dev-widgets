/// Parses `git status --porcelain=v2 --branch`, the format Git
/// keeps stable for scripts.
public enum GitStatusParser {
    public static let ARGUMENTS = [
        "status", "--porcelain=v2", "--branch",
        "--untracked-files=normal",
    ]
    static let UNCHANGED_CODE: Character = "."

    public static func parseBranch(
        status_Text: String
    ) -> BranchStatus {
        var branch = BranchStatus()
        for line in status_Text.split(whereSeparator: \.isNewline)
        where line.hasPrefix("# branch.") {
            applyHeader(line.dropFirst(9), to: &branch)
        }
        return branch
    }

    /// "head main", "oid 1a2b...", "upstream origin/main",
    /// "ab +2 -1". "(detached)" and "(initial)" mean no value.
    static func applyHeader(
        _ header: Substring,
        to branch: inout BranchStatus
    ) {
        let parts = header.split(separator: " ")
        guard let key = parts.first, parts.count > 1 else { return }
        let value = parts[1].hasPrefix("(") ? nil : String(parts[1])
        switch key {
        case "head": branch.name = value
        case "oid": branch.commit_ID = value
        case "upstream": branch.upstream = value
        case "ab" where parts.count == 3:
            branch.ahead_Count = Int(parts[1].dropFirst()) ?? 0
            branch.behind_Count = Int(parts[2].dropFirst()) ?? 0
        default: return
        }
    }

    public static func parseChanges(
        status_Text: String
    ) -> ChangeCounts {
        var changes = ChangeCounts()
        for line in status_Text.split(whereSeparator: \.isNewline) {
            switch line.first {
            case "1", "2": countTracked(line, in: &changes)
            case "u": changes.conflicted += 1
            case "?": changes.untracked += 1
            default: continue
            }
        }
        return changes
    }

    /// "1 M. ..." -> staged; "1 .M ..." -> modified; "1 MM" both.
    static func countTracked(
        _ line: Substring,
        in changes: inout ChangeCounts
    ) {
        let codes = Array(line.dropFirst(2).prefix(2))
        guard codes.count == 2 else { return }
        if codes[0] != UNCHANGED_CODE { changes.staged += 1 }
        if codes[1] != UNCHANGED_CODE { changes.modified += 1 }
    }
}
