import Foundation

/// What one refresh produced: the context to show and, when the
/// branch's CI has just failed, the notification to post.
public struct ContextRefresh: Sendable {
    public let context: DeveloperContext
    public let ci_Alert: CIFailureAlert?
}

/// The developer-context cycle both apps share: containers, ports
/// and Git on every call (every 10 s), the branch's GitHub status
/// when its schedule says so, the review queue every 5 minutes,
/// and failed CI through `CIFailureMonitor`. One GitHub client
/// lives as long as the refresher, so its ETag cache pays off.
public actor DeveloperContextRefresher {
    private let reader: DeveloperContextReader
    private var github_Client: GitHubClient?
    private var github_Schedule = GitHubSchedule()
    private var github_State = GitHubState.not_Configured
    private var queue_Schedule =
        DeveloperContextRefresher
        .makeQueueSchedule()
    private var queue_State = ReviewQueueState.not_Loaded
    private var ci_Monitor = CIFailureMonitor()

    public init(
        reader: DeveloperContextReader = DeveloperContextReader(),
        github_Client: GitHubClient?
    ) {
        self.reader = reader
        self.github_Client = github_Client
    }

    static func makeQueueSchedule() -> GitHubSchedule {
        GitHubSchedule(
            interval_Seconds: ReviewQueueReader.INTERVAL_SECONDS
        )
    }

    public func refresh(project_URL: URL?) async -> ContextRefresh {
        var context = await reader.readInBackground(
            project_URL: project_URL
        )
        context.github = await refreshGitHub(git: context.git)
        context.review_Queue = await refreshReviewQueue()
        let ci_Alert = ci_Monitor.evaluate(context.github, at: Date())
        return ContextRefresh(context: context, ci_Alert: ci_Alert)
    }

    /// After the token changed: a new client, asked right away.
    public func replaceClient(_ client: GitHubClient?) {
        github_Client = client
        github_Schedule = GitHubSchedule()
        queue_Schedule = Self.makeQueueSchedule()
    }

    /// Asks GitHub only when due; otherwise repeats the last answer.
    private func refreshGitHub(git: GitState) async -> GitHubState {
        let schedule_Key = GitHubSchedule.makeKey(git: git)
        let now = Date()
        guard github_Schedule.isDue(key: schedule_Key, at: now) else {
            return github_State
        }
        let state = await GitHubReader(client: github_Client)
            .readState(git: git)
        github_Schedule.record(state, key: schedule_Key, at: now)
        github_State = state
        return state
    }

    private func refreshReviewQueue() async -> ReviewQueueState {
        let now = Date()
        guard queue_Schedule.isDue(key: "", at: now) else {
            return queue_State
        }
        let state = await ReviewQueueReader(client: github_Client)
            .readState()
        queue_Schedule.record(state.schedule_State, key: "", at: now)
        queue_State = state
        return state
    }
}
