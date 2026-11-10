import DevWidgetsCore
import Foundation
import Testing
@testable import DevWidgetsPresentation

/// The macOS presentation code, compiled and run on Linux.
struct GitHubPresentationTests {
    static func makeRun(
        _ outcome: CheckOutcome,
        name: String
    )
        -> WorkflowRunSummary
    {
        var run = WorkflowRunSummary(
            run_ID: 1,
            workflow_Name: name,
            outcome: outcome
        )
        run.page_URL = URL(string: "https://github.com/a/b/runs/1")
        return run
    }

    static func makeStatus(
        runs: [WorkflowRunSummary],
        review: ReviewDecision
    ) -> GitHubStatus {
        var status = GitHubStatus(
            repository: GitHubRepository(owner: "a", name: "b"),
            branch_Name: "feature",
            runs: runs
        )
        var pull_Request = PullRequestSummary(
            number: 42,
            title: "Charts",
            is_Draft: false
        )
        pull_Request.page_URL = URL(
            string: "https://github.com/a/b/pull/42"
        )
        pull_Request.review = review
        status.pull_Request = pull_Request
        return status
    }

    @Test func failingCIIsRedAndLinksTheRun() {
        let status = Self.makeStatus(
            runs: [
                Self.makeRun(.success, name: "Lint"),
                Self.makeRun(.failure, name: "Tests"),
            ],
            review: .approved
        )
        let line = GitHubPresentation.describe(
            .available(status: status)
        )
        #expect(line.title == "PR #42 · Approved")
        #expect(line.detail_Text == "CI failing: Tests")
        #expect(line.level == .critical)
        let page_URL = GitHubPresentation.findPage(
            .available(status: status)
        )
        #expect(page_URL?.path == "/a/b/runs/1")
    }

    @Test func changesRequestedIsAmber() {
        let status = Self.makeStatus(
            runs: [Self.makeRun(.success, name: "Tests")],
            review: .changes_Requested
        )
        let line = GitHubPresentation.describe(
            .available(status: status)
        )
        #expect(line.title == "PR #42 · Changes requested")
        #expect(line.detail_Text == "CI passing (1)")
        #expect(line.level == .elevated)
    }

    @Test func problemsExplainThemselves() {
        let missing = GitHubPresentation.describe(.no_Credentials)
        let rejected = GitHubPresentation.describe(.unauthorized)
        #expect(
            missing.detail_Text == "Run gh auth login or add a token"
        )
        #expect(rejected.level == .elevated)
        let limited = GitHubPresentation.describe(
            .rate_Limited(reset_At: nil)
        )
        #expect(limited.detail_Text == "Rate limited until later")
    }

    @Test func cancelledRunIsNotCalledPassing() {
        let runs = [
            Self.makeRun(.success, name: "Lint"),
            Self.makeRun(.cancelled, name: "Tests"),
        ]
        #expect(
            GitHubPresentation.describeRuns(runs)
                == "CI cancelled: Tests"
        )
    }
}

struct ActionStyleTests {
    static let DATABASE = ContainerIdentity(
        container_ID: "1",
        name: "db",
        image: "postgres"
    )

    @Test func everyActionHasSymbolAndExplanation() {
        let actions: [WidgetAction] = [
            .open_Project,
            .terminate_Process(
                process: ProcessIdentity(pid: 812, name: "node")
            ),
            .stop_Container(container: Self.DATABASE),
            .restart_Container(container: Self.DATABASE),
        ]
        for action in actions {
            #expect(!action.symbol_Name.isEmpty)
            #expect(!action.consequence_Text.isEmpty)
        }
        #expect(actions[1].title == "Quit node")
    }
}

struct PreviewDataTests {
    /// The previews are built through the real recorder.
    @Test func previewSnapshotAndContextExist() {
        #expect(PreviewData.SNAPSHOT != nil)
        #expect(
            ContextPresentation.describeGit(PreviewData.CONTEXT.git)
                .title == "devwidgets · feature/charts"
        )
    }

    /// A minute of varied history, ending on the gallery's values.
    @Test func previewHistoryHasAShape() throws {
        let snapshot = try #require(PreviewData.SNAPSHOT)
        let cpu_Values = snapshot.history.cpu_Fractions
        #expect(cpu_Values.count == PreviewData.HISTORY_SECONDS)
        #expect(Set(cpu_Values.map { Int($0 * 100) }).count > 10)
        let readings = snapshot.readings
        #expect(abs(readings.cpu.total_Fraction - 0.42) < 0.005)
        #expect(
            readings.memory.physical.used_Bytes
                == 11 * PreviewData.GIGABYTE
        )
        let download_Rate = readings.network.download_Bytes_Per_Second
        #expect(abs(download_Rate - 2_500_000) < 1)
    }
}

struct ReviewQueuePresentationTests {
    static func makeQueue(total_Count: Int) -> ReviewQueue {
        let request = ReviewRequest(
            repository: GitHubRepository(owner: "a", name: "api"),
            number: 7,
            title: "Retry uploads"
        )
        return ReviewQueue(
            total_Count: total_Count,
            requests: total_Count > 0 ? [request] : []
        )
    }

    @Test func waitingRequestsAreAmber() {
        let line = ReviewQueuePresentation.describe(
            .available(queue: Self.makeQueue(total_Count: 3))
        )
        #expect(line.detail_Text == "3 requests await you")
        #expect(line.level == .elevated)
        let empty_Line = ReviewQueuePresentation.describe(
            .available(queue: Self.makeQueue(total_Count: 0))
        )
        #expect(empty_Line.level == .normal)
    }

    @Test func requestRowNamesRepositoryAndNumber() {
        let queue = Self.makeQueue(total_Count: 1)
        let rows = ReviewQueuePresentation.listRequests(
            .available(queue: queue),
            limit: 3
        )
        #expect(
            rows.map(ReviewQueuePresentation.describeRequest).first
                == ContextLine(
                    title: "api #7",
                    detail_Text: "Retry uploads"
                )
        )
    }

    @Test func problemsKeepTheirExplanation() {
        let line = ReviewQueuePresentation.describe(
            .failed(problem: .no_Credentials)
        )
        #expect(line.title == "Reviews")
        #expect(
            line.detail_Text == "Run gh auth login or add a token"
        )
    }
}

struct ServerPresentationTests {
    @Test func previewServerShowsGaugesAndDetail() throws {
        let line = ServerPresentation.describe(
            PreviewData.SERVERS.reports[0]
        )
        #expect(line.alias == "web-1")
        #expect(line.detail_Text == "2 cores · load 0.42 · up 3 d")
        #expect(
            line.gauges.map(\.value_Text) == ["18%", "38%", "40%"]
        )
        #expect(line.level == .normal)
    }

    @Test func failedServerSaysWhatToDo() {
        let line = ServerPresentation.describe(
            PreviewData.SERVERS.reports[1]
        )
        #expect(
            line.detail_Text == "Key refused: is it in ssh-agent?"
        )
        #expect(line.level == .critical)
    }

    @Test(arguments: [
        (600.0, "10 min"), (7_200.0, "2 h"), (259_200.0, "3 d"),
    ])
    func uptimeUsesTheLargestUsefulUnit(
        seconds: Double,
        uptime_Text: String
    ) {
        #expect(
            ServerPresentation.describeUptime(seconds) == uptime_Text
        )
    }

    @Test func fullDiskTurnsTheRowRed() {
        var snapshot = PreviewData.makeServerSnapshot()
        snapshot = RemoteSnapshot(
            cpu: snapshot.cpu,
            memory: snapshot.memory,
            disk_Space: Capacity(used_Bytes: 97, total_Bytes: 100)
        )
        let line = ServerPresentation.describeStatus(
            RemoteHostStatus(snapshot: snapshot),
            alias: "db-1"
        )
        #expect(line.level == .critical)
        #expect(line.gauges[0].value_Text == "—")
    }
}
