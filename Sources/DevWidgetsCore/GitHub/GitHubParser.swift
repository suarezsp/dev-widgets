import Foundation

/// Turns GitHub REST JSON into the summaries the widget shows.
public enum GitHubParser {
    static let PENDING_STATUSES: Set = [
        "queued", "in_progress", "waiting", "requested", "pending",
    ]
    static let FAILED_CONCLUSIONS: Set = [
        "failure", "timed_out", "startup_failure", "action_required",
    ]

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// The first open pull request of a `pulls?head=` query.
    public static func parsePullRequest(
        _ json_Data: Data
    ) throws -> PullRequestSummary? {
        let payloads = try makeDecoder().decode(
            [PullRequestPayload].self,
            from: json_Data
        )
        return payloads.first.map {
            var pull_Request = PullRequestSummary(
                number: $0.number,
                title: $0.title,
                is_Draft: $0.draft ?? false
            )
            pull_Request.page_URL = $0.html_URL
            return pull_Request
        }
    }

    /// Runs come newest first. Only the newest commit counts, and
    /// only its newest run of each workflow (re-runs replace).
    public static func parseRuns(
        _ json_Data: Data
    ) throws -> [WorkflowRunSummary] {
        let payloads = try makeDecoder().decode(
            WorkflowRunsPayload.self,
            from: json_Data
        ).workflow_Runs
        guard let newest_SHA = payloads.first?.head_SHA else {
            return []
        }
        var seen_Names: Set<String> = []
        return
            payloads
            .filter { $0.head_SHA == newest_SHA }
            .filter { seen_Names.insert($0.name ?? "").inserted }
            .map(makeRun)
    }

    static func makeRun(
        _ payload: WorkflowRunPayload
    ) -> WorkflowRunSummary {
        var run = WorkflowRunSummary(
            run_ID: payload.run_ID,
            workflow_Name: payload.name ?? "Workflow",
            outcome: decideOutcome(
                status: payload.status,
                conclusion: payload.conclusion
            )
        )
        run.head_SHA = payload.head_SHA
        run.page_URL = payload.html_URL
        return run
    }

    static func decideOutcome(
        status: String?,
        conclusion: String?
    ) -> CheckOutcome {
        if let status, PENDING_STATUSES.contains(status) {
            return .pending
        }
        switch conclusion {
        case "success": return .success
        case "cancelled": return .cancelled
        case let word? where FAILED_CONCLUSIONS.contains(word):
            return .failure
        default: return .skipped
        }
    }

    /// Reviews come oldest first; a reviewer's last approval or
    /// change request counts, and a dismissal clears it.
    public static func parseReviewDecision(
        _ json_Data: Data
    ) throws -> ReviewDecision {
        let reviews = try makeDecoder().decode(
            [ReviewPayload].self,
            from: json_Data
        )
        var decisions: [String: String] = [:]
        for review in reviews {
            let login = review.user?.login ?? ""
            switch review.state {
            case "APPROVED", "CHANGES_REQUESTED":
                decisions[login] = review.state
            case "DISMISSED": decisions[login] = nil
            default: continue
            }
        }
        let states = Set(decisions.values)
        if states.contains("CHANGES_REQUESTED") {
            return .changes_Requested
        }
        return states.contains("APPROVED") ? .approved : .none
    }
}
