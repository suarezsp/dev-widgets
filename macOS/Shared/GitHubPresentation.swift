import DevWidgetsCore
import Foundation

/// GitHub's line in the panel and the context widget: the branch's
/// pull request on top, its CI below.
public enum GitHubPresentation {
    public static func describe(_ github: GitHubState) -> ContextLine
    {
        switch github {
        case .available(let status): describeStatus(status)
        case .rate_Limited(let reset_At): describeRateLimit(reset_At)
        case .unauthorized:
            ContextLine(
                title: "GitHub",
                detail_Text: "Token rejected: check Settings",
                level: .elevated
            )
        default:
            ContextLine(
                title: "GitHub",
                detail_Text: describeQuietState(github)
            )
        }
    }

    /// States that need no attention, only an explanation.
    public static func describeQuietState(
        _ github: GitHubState
    ) -> String {
        switch github {
        case .not_GitHub: "Remote not on GitHub"
        case .no_Credentials: "Run gh auth login or add a token"
        case .unavailable(let reason): reason
        default: "No branch remote"
        }
    }

    public static func describeRateLimit(
        _ reset_At: Date?
    ) -> ContextLine {
        let time_Text =
            reset_At?.formatted(date: .omitted, time: .shortened)
            ?? "later"
        return ContextLine(
            title: "GitHub",
            detail_Text: "Rate limited until \(time_Text)",
            level: .elevated
        )
    }

    /// Failing CI is red; changes requested or CI running amber.
    public static func describeStatus(
        _ status: GitHubStatus
    ) -> ContextLine {
        let ci_Outcome = status.ci_Outcome
        let review = status.pull_Request?.review
        let level: LoadLevel =
            ci_Outcome == .failure
            ? .critical
            : (review == .changes_Requested || ci_Outcome == .pending)
                ? .elevated : .normal
        return ContextLine(
            title: describePullRequest(status.pull_Request),
            detail_Text: describeRuns(status.runs),
            level: level
        )
    }

    /// "PR #42 · Approved", "PR #42 · Draft", "No pull request".
    public static func describePullRequest(
        _ pull_Request: PullRequestSummary?
    ) -> String {
        guard let pull_Request else { return "No pull request" }
        let state_Text =
            pull_Request.is_Draft
            ? "Draft" : describeReview(pull_Request.review)
        return "PR #\(pull_Request.number) · \(state_Text)"
    }

    public static func describeReview(
        _ review: ReviewDecision
    ) -> String {
        switch review {
        case .approved: "Approved"
        case .changes_Requested: "Changes requested"
        case .none: "Awaiting review"
        }
    }

    /// "CI failing: Tests", "CI running: Lint", "CI passing (3)".
    /// A cancelled run is not a pass (phase 4 said "passing").
    public static func describeRuns(
        _ runs: [WorkflowRunSummary]
    ) -> String {
        if let failed_Run = runs.first(where: {
            $0.outcome == .failure
        }) {
            return "CI failing: \(failed_Run.workflow_Name)"
        }
        if let running_Run = runs.first(where: {
            $0.outcome == .pending
        }) {
            return "CI running: \(running_Run.workflow_Name)"
        }
        if let cancelled_Run = runs.first(where: {
            $0.outcome == .cancelled
        }) {
            return "CI cancelled: \(cancelled_Run.workflow_Name)"
        }
        return runs.isEmpty
            ? "No CI runs" : "CI passing (\(runs.count))"
    }

    /// Where a tap on the row goes: the failing run, else the PR.
    public static func findPage(_ github: GitHubState) -> URL? {
        guard case .available(let status) = github else { return nil }
        let failed_Run = status.runs.first { $0.outcome == .failure }
        return failed_Run?.page_URL ?? status.pull_Request?.page_URL
            ?? status.runs.first?.page_URL
    }
}
