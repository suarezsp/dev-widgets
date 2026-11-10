import Foundation
import Testing
@testable import DevWidgetsCore

struct GitHubClientTests {
    @Test func secondReadOfQuietBranchIsAllNotModified() async {
        let transport = GitHubReaderTests.makeRecordedTransport()
        let client = GitHubClient(transport: transport)
        let reader = GitHubReader(client: client)
        let git = GitHubReaderTests.makeGit()
        let first_State = await reader.readState(git: git)
        let second_State = await reader.readState(git: git)
        #expect(first_State == second_State)
        #expect(await client.request_Count == 6)
        #expect(await client.not_Modified_Count == 3)
        #expect(transport.etags.prefix(3).allSatisfy { $0 == nil })
        #expect(transport.etags.suffix(3).allSatisfy { $0 != nil })
    }

    @Test func oldestPageIsEvictedPastTheLimit() async throws {
        let transport = FakeGitHubTransport(rules: [
            ("pulls", "pulls-none.json")
        ])
        let client = GitHubClient(transport: transport)
        for page_Index in 0...GitHubClient.MAX_CACHED_PAGES {
            _ = try await client.fetch("pulls?page=\(page_Index)")
        }
        let newest_Path =
            "pulls?page=\(GitHubClient.MAX_CACHED_PAGES)"
        _ = try await client.fetch("pulls?page=0")
        _ = try await client.fetch(newest_Path)
        #expect(
            transport.etags.suffix(2) == [nil, "e:pulls-none.json"]
        )
    }

    @Test func notModifiedWithoutCacheIsAnError() async {
        let client = GitHubClient(transport: NotModifiedTransport())
        await #expect(throws: GitHubError.self) {
            try await client.fetch("repos/o/n/pulls")
        }
    }
}

/// Always answers 304, as a confused proxy could.
struct NotModifiedTransport: GitHubTransport {
    func fetch(
        _ path: String,
        etag: String?
    ) async throws -> GitHubPage {
        .not_Modified
    }
}

struct GhIncludeTests {
    @Test func headersGiveETagAndBody() throws {
        let output = try Fixtures.rootText(
            "github/gh-include-200.txt"
        )
        let page = GhIncludeParser.parsePage(output)
        guard case .modified(let body, let etag) = page else {
            Issue.record("expected a body, got \(page)")
            return
        }
        #expect(etag?.hasPrefix("W/\"9332144a") == true)
        let pull_Request = try GitHubParser.parsePullRequest(body)
        #expect(pull_Request?.number == 1322)
    }

    @Test func http304FromGhIsNotModified() async throws {
        let error_Text = try Fixtures.rootText(
            "github/gh-http-304.txt"
        )
        let transport = GhCommandTransport(
            runner: FailingCommandRunner(error_Text: error_Text),
            gh_URL: URL(fileURLWithPath: "/usr/bin/gh")
        )
        let page = try await transport.fetch("repos/o/n", etag: "x")
        #expect(page == .not_Modified)
    }

    @Test func requestWithoutETagSendsNoHeader() {
        #expect(
            GhCommandTransport.makeArguments(path: "user", etag: nil)
                == ["api", "-i", "user"]
        )
    }

    @Test func slowGhDoesNotHoldConcurrencyThreads() async throws {
        let runner = SlowCommandRunner(seconds: 0.3)
        let command_Count =
            4
            * ProcessInfo.processInfo
            .activeProcessorCount
        let start_Date = Date()
        try await withThrowingTaskGroup { group in
            for _ in 0..<command_Count {
                group.addTask {
                    try await runner.runInBackground(
                        Command(
                            executable_URL: URL(
                                fileURLWithPath: "/x"
                            ),
                            arguments: ["api"]
                        )
                    )
                }
            }
            try await group.waitForAll()
        }
        // Blocking the pool would take 4 x 0.3 s at least.
        #expect(Date().timeIntervalSince(start_Date) < 0.9)
    }
}

/// Fails every command with a recorded error text.
struct FailingCommandRunner: CommandRunner {
    let error_Text: String

    func run(_ command: Command) throws -> String {
        throw CommandError.failed(
            exit_Status: 1,
            error_Text: error_Text
        )
    }
}

struct ReviewQueueTests {
    static func makeTransport(
        _ file_Name: String
    ) -> FakeGitHubTransport {
        FakeGitHubTransport(rules: [("search/issues", file_Name)])
    }

    @Test func recordedSearchGivesQueueAcrossRepositories() async {
        let transport = Self.makeTransport(
            "search-review-requested.json"
        )
        let state = await ReviewQueueReader(
            client: GitHubClient(transport: transport)
        ).readState()
        guard case .available(let queue) = state else {
            Issue.record("expected a queue, got \(state)")
            return
        }
        #expect(queue.total_Count == 98)
        // The fifth recorded match is a draft, not ready yet.
        #expect(queue.requests.count == 4)
        let first_Request = queue.requests.first
        #expect(
            first_Request?.repository.full_Name
                == "swiftlang/indexstore-db"
        )
        #expect(first_Request?.number == 308)
        #expect(first_Request?.author_Login == "rintaro")
    }

    @Test func pathAsksForMyReviewsNewestFirst() async {
        let transport = Self.makeTransport("search-none.json")
        let state = await ReviewQueueReader(
            client: GitHubClient(transport: transport)
        ).readState()
        let path = transport.paths.first ?? ""
        #expect(
            state
                == .available(
                    queue: ReviewQueue(total_Count: 0, requests: [])
                )
        )
        #expect(path.contains("review-requested:@me"))
        #expect(path.contains("is:pr%20is:open"))
        #expect(
            path.hasSuffix("&sort=updated&order=desc&per_page=10")
        )
    }

    @Test func draftsAndForeignURLsAreLeftOut() throws {
        let json_Text = """
            {"total_count": 2, "items": [
              {"number": 1, "title": "WIP", "draft": true,
               "repository_url": "https://api.github.com/repos/a/b"},
              {"number": 2, "title": "Odd",
               "repository_url": "https://example.com/a/b"}
            ]}
            """
        let queue = try ReviewQueueParser.parseQueue(
            Data(json_Text.utf8)
        )
        #expect(queue.total_Count == 2)
        #expect(queue.requests.isEmpty)
    }

    @Test func noCredentialsAndLimitsBecomeProblems() async throws {
        let no_Client = await ReviewQueueReader(client: nil)
            .readState()
        let transport = Self.makeTransport("search-none.json")
        transport.failure = .rate_Limited(reset_At: nil)
        let limited = await ReviewQueueReader(
            client: GitHubClient(transport: transport)
        ).readState()
        #expect(no_Client == .failed(problem: .no_Credentials))
        #expect(
            limited.schedule_State == .rate_Limited(reset_At: nil)
        )
        let anonymous_Body = try Fixtures.rootText(
            "github/search-me-anonymous-422.json"
        )
        #expect(throws: DecodingError.self) {
            try ReviewQueueParser.parseQueue(
                Data(anonymous_Body.utf8)
            )
        }
    }

    @Test func queueScheduleIsSlowerThanBranch() {
        var schedule = GitHubSchedule(
            interval_Seconds: ReviewQueueReader.INTERVAL_SECONDS
        )
        let start_Date = Date(timeIntervalSinceReferenceDate: 0)
        schedule.record(.not_Configured, key: "", at: start_Date)
        #expect(
            !schedule.isDue(
                key: "",
                at: start_Date.addingTimeInterval(299)
            )
        )
        #expect(
            schedule.isDue(
                key: "",
                at: start_Date.addingTimeInterval(300)
            )
        )
    }
}
