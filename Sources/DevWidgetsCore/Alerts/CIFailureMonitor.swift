import Foundation

/// One failed-CI notification for the chosen project's branch.
public struct CIFailureAlert: Equatable, Sendable {
    public let status: GitHubStatus

    public init(status: GitHubStatus) {
        self.status = status
    }

    public var failed_Runs: [WorkflowRunSummary] {
        status.runs.filter { $0.outcome == .failure }
    }

    /// One notification per branch: a new failure replaces the
    /// previous one in Notification Center.
    public var identifier: String {
        "ci.\(status.repository.full_Name)#\(status.branch_Name)"
    }

    /// Where a click on the notification goes.
    public var page_URL: URL? {
        failed_Runs.first?.page_URL ?? status.pull_Request?.page_URL
    }

    /// "CI failed on main" / "Tests, Lint · acme/api".
    public var message: AlertMessage {
        let workflow_Names = failed_Runs.map(\.workflow_Name)
        return AlertMessage(
            title: "CI failed on \(status.branch_Name)",
            body: workflow_Names.joined(separator: ", ")
                + " · \(status.repository.full_Name)"
        )
    }
}

/// Failed-CI notifications, with the threshold alerts' debounce
/// (`AlertTracker`): one tracker per repository and branch.
public struct CIFailureMonitor: Sendable {
    /// A failure is final, so it needs no sustain. The cooldown
    /// keeps a flapping workflow (re-run, fail, re-run) to one
    /// notification per 5 minutes.
    public static let TIMING = AlertTiming(
        sustain_Seconds: 0,
        cooldown_Seconds: 300
    )

    private var trackers: [String: AlertTracker] = [:]

    public init() {}

    /// The first answer for a branch is only remembered: CI that
    /// was already red at launch or when the project was chosen
    /// does not notify.
    public mutating func evaluate(
        _ github: GitHubState,
        at now: Date
    ) -> CIFailureAlert? {
        guard case .available(let status) = github,
            let outcome = status.ci_Outcome
        else { return nil }
        let key =
            "\(status.repository.full_Name)#\(status.branch_Name)"
        let condition = Self.classify(outcome)
        var tracker = trackers[key] ?? AlertTracker()
        defer { trackers[key] = tracker }
        guard trackers[key] != nil else {
            if condition == .breached { tracker.acknowledge() }
            return nil
        }
        let should_Notify = tracker.update(
            condition,
            at: now,
            timing: Self.TIMING
        )
        return should_Notify ? CIFailureAlert(status: status) : nil
    }

    /// A new run (pending) or a green one re-arms; a cancelled or
    /// skipped run says nothing either way.
    static func classify(_ outcome: CheckOutcome) -> AlertCondition {
        switch outcome {
        case .failure: .breached
        case .pending, .success: .recovered
        case .cancelled, .skipped: .between
        }
    }
}
