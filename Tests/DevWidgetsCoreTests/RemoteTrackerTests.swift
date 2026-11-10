import Foundation
import Testing
@testable import DevWidgetsCore

/// Hosts and recorded polls shared by the tracker tests.
enum RemoteSamples {
    static func makeHost(_ alias: String) throws -> RemoteHost {
        try #require(RemoteHost(alias: alias))
    }

    /// The two recorded polls, 5 s apart.
    static func readPair() throws -> (RemoteSnapshot, RemoteSnapshot)
    {
        var first = try RemoteProbeTests.readSnapshot(
            "probe-linux-1.txt"
        )
        var second = try RemoteProbeTests.readSnapshot(
            "probe-linux-2.txt"
        )
        first.captured_At = Date(timeIntervalSinceReferenceDate: 0)
        second.captured_At = Date(timeIntervalSinceReferenceDate: 5)
        return (first, second)
    }

    static func makeOverview(
        _ host: RemoteHost,
        _ state: RemoteHostState
    ) -> ServerOverview {
        ServerOverview(reports: [
            RemoteHostReport(host: host, state: state)
        ])
    }

    static func findStatus(
        _ overview: ServerOverview,
        at index: Int = 0
    ) throws -> RemoteHostStatus {
        guard
            case .available(let status) = overview.reports[index]
                .state
        else { throw RemoteProblem.unreachable(reason: "no status") }
        return status
    }
}

struct RemoteTrackerTests {
    @Test func cpuAndNetworkNeedTwoPolls() throws {
        let (first, second) = try RemoteSamples.readPair()
        let web = try RemoteSamples.makeHost("web-1")
        var tracker = RemoteTracker()
        let early = try RemoteSamples.findStatus(
            tracker.update(
                hosts: [web],
                results: [web: .success(first)]
            )
        )
        let later = try RemoteSamples.findStatus(
            tracker.update(
                hosts: [web],
                results: [web: .success(second)]
            )
        )
        #expect(early.cpu_Fraction == nil)
        let cpu_Fraction = try #require(later.cpu_Fraction)
        #expect(cpu_Fraction >= 0 && cpu_Fraction <= 1)
        #expect(later.network != nil)
        #expect(later.core_Count == 8)
    }

    @Test func failedAndMissingHostsKeepTheirPlace() throws {
        let web = try RemoteSamples.makeHost("web-1")
        let hosts = [web, try RemoteSamples.makeHost("db")]
        var tracker = RemoteTracker()
        let failed = tracker.update(
            hosts: hosts,
            results: [web: .failure(.authentication_Failed)]
        )
        #expect(failed.reports.map(\.host) == hosts)
        #expect(
            failed.reports.map(\.state) == [
                .failed(problem: .authentication_Failed), .not_Loaded,
            ]
        )
    }

    @Test func failureForgetsThePreviousPoll() throws {
        let (first, second) = try RemoteSamples.readPair()
        let web = try RemoteSamples.makeHost("web-1")
        var tracker = RemoteTracker()
        _ = tracker.update(
            hosts: [web],
            results: [web: .success(first)]
        )
        _ = tracker.update(
            hosts: [web],
            results: [web: .failure(.authentication_Failed)]
        )
        let recovered = try RemoteSamples.findStatus(
            tracker.update(
                hosts: [web],
                results: [web: .success(second)]
            )
        )
        #expect(recovered.cpu_Fraction == nil)
    }

    @Test func readerAnswersInParallel() async throws {
        let probe_Text = try Fixtures.rootText(
            "ssh/probe-linux-1.txt"
        )
        let reader = SSHReader(
            runner: FakeCommandRunner(outputs: ["-o": probe_Text]),
            ssh_URL: URL(fileURLWithPath: "/usr/bin/ssh")
        )
        let web = try RemoteSamples.makeHost("web-1")
        let hosts = [web, try RemoteSamples.makeHost("db")]
        let results = await reader.readAll(hosts)
        #expect(results.count == 2)
        #expect((try? results[web]?.get()) != nil)
    }

    @Test func readerReportsMissingSshAndRefusals() async throws {
        let error_Text = try Fixtures.rootText(
            "ssh/error-permission-denied.txt"
        )
        let refusing = SSHReader(
            runner: FailingCommandRunner(error_Text: error_Text),
            ssh_URL: URL(fileURLWithPath: "/usr/bin/ssh")
        )
        let missing = SSHReader(runner: refusing.runner, ssh_URL: nil)
        let web = try RemoteSamples.makeHost("web-1")
        #expect(
            await refusing.read(web)
                == .failure(.authentication_Failed)
        )
        #expect(await missing.read(web) == .failure(.ssh_Missing))
    }

    @Test func serverShapeIgnoresSmallChanges() throws {
        let (first, second) = try RemoteSamples.readPair()
        let web = try RemoteSamples.makeHost("web-1")
        let up = RemoteSamples.makeOverview(
            web,
            .available(status: RemoteHostStatus(snapshot: first))
        )
        let still_Up = RemoteSamples.makeOverview(
            web,
            .available(status: RemoteHostStatus(snapshot: second))
        )
        let down = RemoteSamples.makeOverview(
            web,
            .failed(problem: .host_Key_Rejected)
        )
        #expect(ServerShape(up) == ServerShape(still_Up))
        #expect(ServerShape(up) != ServerShape(down))
    }
}

/// Real `ssh` against a throwaway local `sshd`, started by
/// `tools/ssh_test_server.sh`, which prints the export of
/// DEVWIDGETS_SSH_TEST_CONFIG. Skipped when it is not set.
@Suite(
    .enabled(
        if: ProcessInfo.processInfo
            .environment["DEVWIDGETS_SSH_TEST_CONFIG"] != nil
    )
)
struct LocalSSHServerTests {
    static func makeReader(control_Directory: URL?) -> SSHReader {
        var reader = SSHReader()
        let config_Path =
            ProcessInfo.processInfo
            .environment["DEVWIDGETS_SSH_TEST_CONFIG"] ?? ""
        reader.options.config_File = URL(fileURLWithPath: config_Path)
        reader.options.control_Directory = control_Directory
        return reader
    }

    @Test func liveServerAnswersAndClosedPortIsUnreachable()
        async throws
    {
        let reader = Self.makeReader(control_Directory: nil)
        let live_Host = try RemoteSamples.makeHost("devwidgets-test")
        let closed_Host = try RemoteSamples.makeHost(
            "devwidgets-closed"
        )
        let results = await reader.readAll([live_Host, closed_Host])
        let snapshot = try? results[live_Host]?.get()
        #expect(snapshot?.system_Text.hasPrefix("Linux") == true)
        #expect(
            results[closed_Host]
                == .failure(
                    .unreachable(reason: "Connection refused")
                )
        )
    }

    @Test func pollsShareOneConnection() async throws {
        let control_URL = URL(
            fileURLWithPath:
                "/tmp/dw-test-\(UUID().uuidString.prefix(8))"
        )
        try FileManager.default.createDirectory(
            at: control_URL,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: control_URL) }
        let reader = Self.makeReader(control_Directory: control_URL)
        let host = try RemoteSamples.makeHost("devwidgets-test")
        _ = await reader.read(host)
        let second_Result = await reader.read(host)
        let sockets = try FileManager.default.contentsOfDirectory(
            atPath: control_URL.path
        )
        #expect((try? second_Result.get()) != nil)
        #expect(sockets.count == 1)
    }

    /// /dev/shm is a tmpfs: its size differs from the root disk.
    @Test func chosenDiskIsMeasured() async throws {
        let reader = Self.makeReader(control_Directory: nil)
        let root_Host = try RemoteSamples.makeHost("devwidgets-test")
        let shm_Host = try #require(
            RemoteHost(
                alias: "devwidgets-test",
                disk_Path: "/dev/shm"
            )
        )
        let results = await reader.readAll([root_Host, shm_Host])
        let root_Snapshot = try #require(
            try? results[root_Host]?.get()
        )
        let shm_Snapshot = try #require(try? results[shm_Host]?.get())
        #expect(
            root_Snapshot.disk_Space.total_Bytes
                != shm_Snapshot.disk_Space.total_Bytes
        )
    }
}
