import Foundation
import Testing
@testable import DevWidgetsCore

/// Fixtures in Tests/Fixtures/github: recorded from the public
/// swiftlang/swift-format repository, or hand-written (see README).
struct GitHubParsingTests {
    static func data(_ name: String) throws -> Data {
        Data(try Fixtures.rootText("github/\(name)").utf8)
    }

    @Test(arguments: [
        ("git@github.com:acme/api.git", "acme/api"),
        ("https://github.com/acme/api.git", "acme/api"),
        ("https://github.com/acme/api", "acme/api"),
        ("ssh://git@github.com/acme/api.git", "acme/api"),
        ("https://user@GitHub.com/acme/api.git\n", "acme/api"),
    ])
    func remoteFormsAreRecognised(remote: String, full_Name: String) {
        let repository = GitRemoteParser.parseRepository(
            remote_URL: remote
        )
        #expect(repository?.full_Name == full_Name)
    }

    @Test(arguments: [
        "git@gitlab.com:acme/api.git",
        "https://github.com/acme",
        "/srv/git/api.git",
    ])
    func otherRemotesAreIgnored(remote: String) {
        #expect(
            GitRemoteParser.parseRepository(remote_URL: remote) == nil
        )
    }

    @Test func recordedPullRequestIsParsed() throws {
        let pull_Request = try GitHubParser.parsePullRequest(
            try Self.data("pulls-branch.json")
        )
        #expect(pull_Request?.number == 1322)
        #expect(pull_Request?.is_Draft == false)
        let none = try GitHubParser.parsePullRequest(
            try Self.data("pulls-none.json")
        )
        #expect(none == nil)
    }

    @Test func recordedFailingBranchKeepsNewestCommit() throws {
        let runs = try GitHubParser.parseRuns(
            try Self.data("runs-branch.json")
        )
        #expect(runs.map(\.run_ID) == [42_547_119_780])
        #expect(runs.first?.outcome == .failure)
    }

    @Test func recordedMainHasTwoGreenWorkflows() throws {
        let runs = try GitHubParser.parseRuns(
            try Self.data("runs-main.json")
        )
        #expect(runs.count == 2)
        #expect(Set(runs.map(\.head_SHA)).count == 1)
        let status = GitHubStatus(
            repository: GitHubRepository(owner: "o", name: "n"),
            branch_Name: "main",
            runs: runs
        )
        #expect(status.ci_Outcome == .success)
    }

    @Test func rerunReplacesOlderRunOfSameWorkflow() throws {
        let runs = try GitHubParser.parseRuns(
            try Self.data("runs-in-progress.json")
        )
        #expect(runs.map(\.run_ID) == [904, 903])
        #expect(runs.map(\.outcome) == [.pending, .success])
    }

    /// "status/conclusion" as GitHub reports them.
    @Test(arguments: [
        ("queued/", CheckOutcome.pending),
        ("completed/success", .success),
        ("completed/timed_out", .failure),
        ("completed/startup_failure", .failure),
        ("completed/cancelled", .cancelled),
        ("completed/neutral", .skipped),
    ])
    func outcomeMergesStatusAndConclusion(
        reported: String,
        outcome: CheckOutcome
    ) {
        let words = reported.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        let decided = GitHubParser.decideOutcome(
            status: String(words[0]),
            conclusion: words[1].isEmpty ? nil : String(words[1])
        )
        #expect(decided == outcome)
    }

    @Test func reviewDecisions() throws {
        let approved = try GitHubParser.parseReviewDecision(
            try Self.data("reviews-approved.json")
        )
        let mixed = try GitHubParser.parseReviewDecision(
            try Self.data("reviews-mixed.json")
        )
        let none = try GitHubParser.parseReviewDecision(
            try Self.data("reviews-none.json")
        )
        #expect(approved == .approved)
        #expect(mixed == .changes_Requested)
        #expect(none == .none)
    }
}

struct GitHubTransportTests {
    static func check(
        _ status_Code: Int,
        _ headers: [String: String] = [:]
    ) -> GitHubError? {
        do {
            try GitHubResponse.check(
                status_Code: status_Code,
                headers: headers
            )
            return nil
        } catch {
            return error as? GitHubError
        }
    }

    @Test func statusCodesMapToErrors() {
        #expect(Self.check(200) == nil)
        #expect(Self.check(401) == .unauthorized)
        #expect(Self.check(403) == .unauthorized)
        #expect(Self.check(404) == .not_Found)
        #expect(Self.check(502) == .unreachable(reason: "HTTP 502"))
    }

    @Test func exhaustedLimitCarriesResetDate() {
        let error = Self.check(
            403,
            [
                "x-ratelimit-remaining": "0",
                "x-ratelimit-reset": "1000",
            ]
        )
        let reset_Date = Date(timeIntervalSince1970: 1_000)
        #expect(error == .rate_Limited(reset_At: reset_Date))
    }

    @Test func secondaryLimitUsesRetryAfter() throws {
        let error = Self.check(429, ["retry-after": "60"])
        guard case .rate_Limited(let reset_At?) = error else {
            let error_Text = String(describing: error)
            Issue.record("expected a reset date, got \(error_Text)")
            return
        }
        #expect(reset_At.timeIntervalSinceNow > 50)
    }

    @Test func recordedGhLoginMessageMeansNoCredentials() throws {
        let error_Text = try Fixtures.rootText(
            "github/gh-not-logged-in.txt"
        )
        #expect(
            GhCommandTransport.classify(error_Text: error_Text)
                == .no_Credentials
        )
    }

    @Test func ghTransportRunsGhApi() async throws {
        let runner = FakeCommandRunner(outputs: ["api": "[]"])
        let transport = GhCommandTransport(
            runner: runner,
            gh_URL: URL(fileURLWithPath: "/usr/bin/gh")
        )
        let page = try await transport.fetch(
            "repos/o/n/pulls",
            etag: "W/\"abc\""
        )
        #expect(page == .modified(body: Data("[]".utf8), etag: nil))
        #expect(
            runner.run_Commands.first?.arguments == [
                "api", "-i", "-H", "If-None-Match: W/\"abc\"",
                "repos/o/n/pulls",
            ]
        )
    }

    @Test func ghHttpErrorsAreClassified() throws {
        let error_Text = try Fixtures.rootText(
            "github/gh-http-404.txt"
        )
        #expect(
            GhCommandTransport.classify(error_Text: error_Text)
                == .not_Found
        )
    }
}
