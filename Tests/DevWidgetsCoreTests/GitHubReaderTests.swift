import Foundation
import Testing
@testable import DevWidgetsCore

struct GitHubReaderTests {
    static let BRANCH_NAME =
        "dependabot/github_actions/swiftlang-actions-717513d5aa"

    static func makeGit(
        branch_Name: String? = BRANCH_NAME,
        remote_URL: String? =
            "https://github.com/swiftlang/swift-format"
    ) -> GitState {
        var branch = BranchStatus()
        branch.name = branch_Name
        var status = GitStatus(
            project_Name: "swift-format",
            branch: branch,
            changes: ChangeCounts()
        )
        status.remote_URL = remote_URL
        return .available(status: status)
    }

    static func makeRecordedTransport() -> FakeGitHubTransport {
        FakeGitHubTransport(rules: [
            ("/reviews", "reviews-approved.json"),
            ("/pulls?", "pulls-branch.json"),
            ("/actions/runs", "runs-branch.json"),
        ])
    }

    @Test func recordedBranchGivesPullRequestAndFailingCI() async {
        let transport = Self.makeRecordedTransport()
        let state = await GitHubReader(
            client: GitHubClient(transport: transport)
        )
        .readState(git: Self.makeGit())
        guard case .available(let status) = state else {
            Issue.record("expected a status, got \(state)")
            return
        }
        #expect(status.pull_Request?.number == 1322)
        #expect(status.pull_Request?.review == .approved)
        #expect(status.ci_Outcome == .failure)
        #expect(transport.paths.count == 3)
    }

    @Test func branchIsEncodedAndForksExcluded() {
        let paths = GitHubPaths(
            repository: GitHubRepository(owner: "acme", name: "api"),
            branch_Name: "fix/a+b&c"
        )
        #expect(
            paths.pull_Request.hasSuffix("&head=acme:fix/a%2Bb%26c")
        )
        #expect(
            paths.workflow_Runs.hasSuffix("&branch=fix/a%2Bb%26c")
        )
    }

    @Test func noPullRequestSkipsReviews() async {
        let transport = FakeGitHubTransport(rules: [
            ("/pulls?", "pulls-none.json"),
            ("/actions/runs", "runs-main.json"),
        ])
        let state = await GitHubReader(
            client: GitHubClient(transport: transport)
        )
        .readState(git: Self.makeGit(branch_Name: "main"))
        guard case .available(let status) = state else {
            Issue.record("expected a status, got \(state)")
            return
        }
        #expect(status.pull_Request == nil)
        #expect(transport.paths.count == 2)
    }

    @Test func statesWithoutRequests() async {
        let transport = Self.makeRecordedTransport()
        let reader = GitHubReader(
            client: GitHubClient(transport: transport)
        )
        let detached = await reader.readState(
            git: Self.makeGit(branch_Name: nil)
        )
        let gitlab = await reader.readState(
            git: Self.makeGit(remote_URL: "git@gitlab.com:a/b.git")
        )
        let no_Project = await reader.readState(git: .not_Configured)
        let no_Transport = await GitHubReader(client: nil)
            .readState(git: Self.makeGit())
        #expect(detached == .not_Configured)
        #expect(gitlab == .not_GitHub)
        #expect(no_Project == .not_Configured)
        #expect(no_Transport == .no_Credentials)
        #expect(transport.paths.isEmpty)
    }

    @Test func transportErrorsBecomeStates() async {
        let transport = Self.makeRecordedTransport()
        let reset_Date = Date(timeIntervalSince1970: 1_000)
        transport.failure = .rate_Limited(reset_At: reset_Date)
        let limited = await GitHubReader(
            client: GitHubClient(transport: transport)
        )
        .readState(git: Self.makeGit())
        transport.failure = .not_Found
        let hidden = await GitHubReader(
            client: GitHubClient(transport: transport)
        )
        .readState(git: Self.makeGit())
        #expect(limited == .rate_Limited(reset_At: reset_Date))
        #expect(
            hidden
                == .unavailable(
                    reason: "Repository not found or private"
                )
        )
    }
}

struct GitHubScheduleTests {
    static let START = Date(timeIntervalSinceReferenceDate: 0)

    @Test func asksOncePerMinutePerBranch() {
        var schedule = GitHubSchedule()
        #expect(schedule.isDue(key: "a", at: Self.START))
        schedule.record(.not_GitHub, key: "a", at: Self.START)
        let later = Self.START.addingTimeInterval(30)
        #expect(!schedule.isDue(key: "a", at: later))
        #expect(schedule.isDue(key: "b", at: later))
        #expect(
            schedule.isDue(key: "a", at: later.addingTimeInterval(30))
        )
    }

    @Test func waitsForRateLimitReset() {
        var schedule = GitHubSchedule()
        let reset_Date = Self.START.addingTimeInterval(3_600)
        schedule.record(
            .rate_Limited(reset_At: reset_Date),
            key: "a",
            at: Self.START
        )
        let before_Reset = reset_Date.addingTimeInterval(-1)
        #expect(!schedule.isDue(key: "a", at: before_Reset))
        #expect(schedule.isDue(key: "a", at: reset_Date))
    }

    @Test func keyFollowsRemoteAndBranch() {
        let key = GitHubSchedule.makeKey(
            git: GitHubReaderTests.makeGit(branch_Name: "main")
        )
        #expect(
            key == "https://github.com/swiftlang/swift-format#main"
        )
        #expect(GitHubSchedule.makeKey(git: .not_Configured).isEmpty)
    }
}
