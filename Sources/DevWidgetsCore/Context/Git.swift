/// Branch line of `git status --porcelain=v2 --branch`.
public struct BranchStatus: Codable, Equatable, Sendable {
    public static let SHORT_COMMIT_LENGTH = 7

    /// nil when HEAD is detached.
    public var name: String?
    public var commit_ID: String?
    public var upstream: String?
    public var ahead_Count = 0
    public var behind_Count = 0

    public init() {}

    public var short_Commit_ID: String? {
        commit_ID.map { String($0.prefix(Self.SHORT_COMMIT_LENGTH)) }
    }
}

/// How many files are in each state.
public struct ChangeCounts: Codable, Equatable, Sendable {
    public var staged = 0
    public var modified = 0
    public var untracked = 0
    public var conflicted = 0

    public init() {}

    public var is_Clean: Bool {
        staged + modified + untracked + conflicted == 0
    }
}

public struct GitStatus: Codable, Equatable, Sendable {
    public let project_Name: String
    public let branch: BranchStatus
    public let changes: ChangeCounts
    /// URL of the upstream's remote (or origin): where GitHub
    /// status comes from.
    public var remote_URL: String?

    public init(
        project_Name: String,
        branch: BranchStatus,
        changes: ChangeCounts
    ) {
        self.project_Name = project_Name
        self.branch = branch
        self.changes = changes
    }
}

public enum GitState: Codable, Equatable, Sendable {
    /// The user has not chosen a project folder yet.
    case not_Configured
    case not_Installed
    case not_A_Repository(project_Name: String)
    case available(status: GitStatus)
}
