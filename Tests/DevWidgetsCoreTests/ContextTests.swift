import Foundation
import Testing
@testable import DevWidgetsCore

struct ContextTests {
    @Test func readerCombinesEverySource() throws {
        let runner = FakeCommandRunner(outputs: [
            "ps": try Fixtures.rootText("docker/ps.jsonl"),
            "stats": try Fixtures.rootText("docker/stats.jsonl"),
            "status": try Fixtures.rootText(
                "git/status-feature-branch.txt"
            ),
        ])
        let reader = DeveloperContextReader(
            runner: runner,
            port_Source: .proc_Tree(Fixtures.PROC_DIRECTORY)
        )
        let context = reader.read(
            project_URL: URL(fileURLWithPath: "/tmp/api")
        )
        #expect(context.ports.count == 3)
        guard case .available(let status) = context.git else {
            Issue.record("expected git status")
            return
        }
        #expect(status.project_Name == "api")
    }

    @Test func missingLsofGivesNoPorts() {
        let reader = DeveloperContextReader(
            runner: FakeCommandRunner(outputs: [:]),
            port_Source: .lsof(nil)
        )
        #expect(reader.readPorts().isEmpty)
    }

    @Test func savedContextLoadsBackUnchanged() throws {
        let context = DeveloperContext(
            docker: .not_Running,
            ports: [
                ListeningPort(port: 3000, address: "*", owner: nil)
            ],
            git: .not_Configured
        )
        let store = ContextStore(
            directory: try GitSandbox.makeFolder()
        )
        try store.save(context)
        #expect(try store.load() == context)
    }
}

struct ReloadThrottleTests {
    static let START = Date(timeIntervalSinceReferenceDate: 0)

    static func makeContext(
        cpu_Fraction: Double,
        port: UInt16
    )
        -> ContextShape
    {
        var container = ContainerUsage(
            identity: ContainerIdentity(
                container_ID: "1",
                name: "db",
                image: "postgres"
            ),
            state: "running"
        )
        container.cpu_Fraction = cpu_Fraction
        let context = DeveloperContext(
            docker: .available(containers: [container]),
            ports: [
                ListeningPort(port: port, address: "*", owner: nil)
            ],
            git: .not_Configured
        )
        return ContextShape(context)
    }

    @Test func numbersAloneDoNotReload() {
        var tracker = ReloadThrottle<ContextShape>(
            min_Reload_Seconds: ContextShape.MIN_RELOAD_SECONDS
        )
        let first = Self.makeContext(cpu_Fraction: 0.1, port: 3000)
        let busier = Self.makeContext(cpu_Fraction: 0.9, port: 3000)
        let first_Reload = tracker.shouldReload(
            for: first,
            at: Self.START
        )
        let busier_Reload = tracker.shouldReload(
            for: busier,
            at: Self.START.addingTimeInterval(60)
        )
        #expect(first_Reload)
        #expect(!busier_Reload)
    }

    @Test func newPortReloadsOutsideMinimumInterval() {
        var tracker = ReloadThrottle<ContextShape>(
            min_Reload_Seconds: ContextShape.MIN_RELOAD_SECONDS
        )
        let first = Self.makeContext(cpu_Fraction: 0.1, port: 3000)
        let moved = Self.makeContext(cpu_Fraction: 0.1, port: 5173)
        _ = tracker.shouldReload(for: first, at: Self.START)
        let soon_Reload = tracker.shouldReload(
            for: moved,
            at: Self.START.addingTimeInterval(10)
        )
        let later_Reload = tracker.shouldReload(
            for: moved,
            at: Self.START.addingTimeInterval(31)
        )
        #expect(!soon_Reload)
        #expect(later_Reload)
    }
}

struct DeveloperContextRefresherTests {
    static func makeRefresher(
        _ transport: FakeGitHubTransport
    ) -> DeveloperContextRefresher {
        DeveloperContextRefresher(
            reader: DeveloperContextReader(
                runner: FakeCommandRunner(outputs: [:]),
                port_Source: .proc_Tree(URL(fileURLWithPath: "/none"))
            ),
            github_Client: GitHubClient(transport: transport)
        )
    }

    @Test func noProjectStillReadsTheReviewQueue() async {
        let transport = ReviewQueueTests.makeTransport(
            "search-review-requested.json"
        )
        let refresher = Self.makeRefresher(transport)
        let refresh = await refresher.refresh(project_URL: nil)
        #expect(refresh.context.git == .not_Configured)
        #expect(refresh.context.github == .not_Configured)
        #expect(refresh.ci_Alert == nil)
        guard
            case .available(let queue) = refresh.context.review_Queue
        else {
            Issue.record("expected the queue")
            return
        }
        #expect(queue.requests.count == 4)
    }

    @Test func queueWaitsForItsIntervalUntilClientChanges() async {
        let transport = ReviewQueueTests.makeTransport(
            "search-none.json"
        )
        let refresher = Self.makeRefresher(transport)
        _ = await refresher.refresh(project_URL: nil)
        _ = await refresher.refresh(project_URL: nil)
        #expect(transport.paths.count == 1)
        await refresher.replaceClient(
            GitHubClient(transport: transport)
        )
        _ = await refresher.refresh(project_URL: nil)
        #expect(transport.paths.count == 2)
    }
}
