import Foundation

/// "owner/name" of a repository on github.com.
public struct GitHubRepository: Codable, Hashable, Sendable {
    public let owner: String
    public let name: String

    public init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    public var full_Name: String { "\(owner)/\(name)" }
}

/// One CI outcome, merged from GitHub's `status` and `conclusion`.
public enum CheckOutcome: String, Codable, Sendable {
    case pending
    case success
    case failure
    case cancelled
    case skipped
}

/// The newest run of one workflow on the branch.
public struct WorkflowRunSummary: Codable, Equatable, Sendable {
    public let run_ID: Int64
    public let workflow_Name: String
    public let outcome: CheckOutcome
    public var head_SHA = ""
    public var page_URL: URL?

    public init(
        run_ID: Int64,
        workflow_Name: String,
        outcome: CheckOutcome
    ) {
        self.run_ID = run_ID
        self.workflow_Name = workflow_Name
        self.outcome = outcome
    }
}

/// Latest decisive review per reviewer, as the PR page shows it.
public enum ReviewDecision: String, Codable, Sendable {
    case none
    case approved
    case changes_Requested
}

public struct PullRequestSummary: Codable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let is_Draft: Bool
    public var page_URL: URL?
    public var review: ReviewDecision = .none

    public init(number: Int, title: String, is_Draft: Bool) {
        self.number = number
        self.title = title
        self.is_Draft = is_Draft
    }
}

/// CI and pull request of the chosen project's current branch.
public struct GitHubStatus: Codable, Equatable, Sendable {
    public let repository: GitHubRepository
    public let branch_Name: String
    public let runs: [WorkflowRunSummary]
    /// nil on branches without an open pull request.
    public var pull_Request: PullRequestSummary?

    public init(
        repository: GitHubRepository,
        branch_Name: String,
        runs: [WorkflowRunSummary]
    ) {
        self.repository = repository
        self.branch_Name = branch_Name
        self.runs = runs
    }

    /// Worst first: one failing workflow makes the branch red.
    public var ci_Outcome: CheckOutcome? {
        let outcomes = Set(runs.map(\.outcome))
        let severity_Order: [CheckOutcome] = [
            .failure, .pending, .cancelled, .success, .skipped,
        ]
        return severity_Order.first { outcomes.contains($0) }
    }
}

/// What the widget can say about GitHub for the chosen project.
public enum GitHubState: Codable, Equatable, Sendable {
    /// No project, detached HEAD or no remote: nothing to ask.
    case not_Configured
    /// The remote is not on github.com.
    case not_GitHub
    /// Neither a token in the Keychain nor a signed-in `gh`.
    case no_Credentials
    case unauthorized
    case rate_Limited(reset_At: Date?)
    case unavailable(reason: String)
    case available(status: GitHubStatus)
}
