import DevWidgetsCore

/// One headline and one detail line, tinted by how much attention
/// it needs: the developer-context counterpart of a metric row.
public struct ContextLine: Equatable {
    public let title: String
    public let detail_Text: String
    public var level = LoadLevel.normal

    public init(
        title: String,
        detail_Text: String,
        level: LoadLevel = .normal
    ) {
        self.title = title
        self.detail_Text = detail_Text
        self.level = level
    }
}

public enum ContextPresentation {
    public static func describeGit(_ git: GitState) -> ContextLine {
        switch git {
        case .not_Configured:
            ContextLine(
                title: "No project",
                detail_Text: "Choose one in the menu bar"
            )
        case .not_Installed:
            ContextLine(title: "Git", detail_Text: "Git not found")
        case .not_A_Repository(let project_Name):
            ContextLine(
                title: project_Name,
                detail_Text: "Not a Git repository",
                level: .elevated
            )
        case .available(let status):
            describeStatus(status)
        }
    }

    /// Conflicts are red, uncommitted work amber, clean green.
    public static func describeStatus(
        _ status: GitStatus
    ) -> ContextLine {
        let branch = status.branch
        let branch_Name =
            branch.name
            ?? "detached at \(branch.short_Commit_ID ?? "?")"
        let level: LoadLevel =
            status.changes.conflicted > 0
            ? .critical
            : status.changes.is_Clean ? .normal : .elevated
        return ContextLine(
            title: "\(status.project_Name) · \(branch_Name)",
            detail_Text: describeChanges(
                status.changes,
                branch: branch
            ),
            level: level
        )
    }

    /// "↑2 · 3 modified · 1 untracked", or "Clean".
    public static func describeChanges(
        _ changes: ChangeCounts,
        branch: BranchStatus
    ) -> String {
        let arrow_Parts = [
            (total: branch.ahead_Count, arrow: "↑"),
            (total: branch.behind_Count, arrow: "↓"),
        ]
        .filter { $0.total > 0 }
        .map { "\($0.arrow)\($0.total)" }
        let change_Parts = [
            (total: changes.conflicted, word: "conflicted"),
            (total: changes.staged, word: "staged"),
            (total: changes.modified, word: "modified"),
            (total: changes.untracked, word: "untracked"),
        ]
        .filter { $0.total > 0 }
        .map { "\($0.total) \($0.word)" }
        let parts = arrow_Parts + change_Parts
        return parts.isEmpty
            ? "Clean" : parts.joined(separator: " · ")
    }

    public static func describeDocker(
        _ docker: DockerState
    ) -> ContextLine {
        switch docker {
        case .not_Installed:
            ContextLine(title: "Docker", detail_Text: "Not installed")
        case .not_Running:
            ContextLine(title: "Docker", detail_Text: "Not running")
        case .available(let containers):
            ContextLine(
                title: "Docker",
                detail_Text:
                    "\(docker.running_Containers.count) running"
                    + " of \(containers.count)"
            )
        }
    }

    public static let OTHER_OWNER_NAME = "other users"

    /// One row per program: a dev server often opens several ports.
    /// Groups keep the order of their lowest port.
    public static func groupPorts(
        _ ports: [ListeningPort]
    ) -> [PortGroup] {
        var groups: [PortGroup] = []
        for port in ports {
            let owner_Name = port.owner?.name ?? OTHER_OWNER_NAME
            if let group_Index = groups.firstIndex(where: {
                $0.owner_Name == owner_Name
            }) {
                groups[group_Index].ports.append(port.port)
            } else {
                groups.append(
                    PortGroup(
                        owner_Name: owner_Name,
                        ports: [port.port]
                    )
                )
            }
        }
        return groups
    }
}

/// The ports one program listens on.
public struct PortGroup: Equatable {
    public let owner_Name: String
    public var ports: [UInt16]

    /// ":5173 :5174".
    public var ports_Text: String {
        ports.map { ":\($0)" }.joined(separator: " ")
    }
}
