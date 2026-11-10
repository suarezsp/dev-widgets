import Foundation
import Testing

@testable import DevWidgetsCore

struct SSHConfigReaderTests {
    /// A throwaway home with ~/.ssh/config including a relative
    /// glob, a "~/" path, a missing file and itself (a loop).
    static func makeHome() throws -> URL {
        let home_URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssh-home-\(UUID().uuidString)")
        try writeFiles(
            in: home_URL.appendingPathComponent(".ssh"),
            [
                "config":
                    "Host main\nInclude conf.d/*.conf ~/.ssh/extra"
                    + "\nInclude missing config\nHost last\n",
                "conf.d/b.conf": "Host beta\n",
                "conf.d/a.conf": "Host alpha *.lan\n",
                "conf.d/notes.txt": "Host ignored\n",
                "extra": "Host extra main\n",
            ]
        )
        return home_URL
    }

    static func writeFiles(
        in ssh_URL: URL,
        _ files: [String: String]
    ) throws {
        for (name, text) in files {
            let file_URL = ssh_URL.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: file_URL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(
                to: file_URL,
                atomically: true,
                encoding: .utf8
            )
        }
    }

    @Test func includesAreFollowedInOrder() throws {
        let home_URL = try Self.makeHome()
        defer { try? FileManager.default.removeItem(at: home_URL) }
        let reader = SSHConfigReader(home_Directory: home_URL)
        #expect(
            reader.listAliases()
                == ["main", "alpha", "beta", "extra", "last"]
        )
    }

    @Test func missingConfigGivesNoAliases() {
        let reader = SSHConfigReader(
            home_Directory: URL(fileURLWithPath: "/nonexistent")
        )
        #expect(reader.listAliases().isEmpty)
    }

    @Test func includeLinesAcceptEqualsAndCase() {
        #expect(
            SSHConfigParser.parseIncludeLine("include=a.conf")
                == ["a.conf"]
        )
        #expect(
            SSHConfigParser.parseIncludeLine("  Include x y")
                == ["x", "y"]
        )
        #expect(SSHConfigParser.parseIncludeLine("Host x").isEmpty)
    }
}

struct ServerDownMonitorTests {
    static let START = Date(timeIntervalSince1970: 1_000)

    static func makeOverview(
        _ state: RemoteHostState
    ) throws -> ServerOverview {
        let host = try RemoteSamples.makeHost("web-1")
        return ServerOverview(
            reports: [RemoteHostReport(host: host, state: state)]
        )
    }

    static let DOWN = RemoteHostState.failed(
        problem: .unreachable(reason: "Connection refused")
    )

    /// Feeds one state every 15 s and returns how many alerts
    /// each poll gave.
    static func feed(
        _ states: [RemoteHostState],
        to monitor: inout ServerDownMonitor
    ) throws -> [Int] {
        try states.enumerated().map { index, state in
            monitor.evaluate(
                try makeOverview(state),
                at: START.addingTimeInterval(Double(index) * 15)
            ).count
        }
    }

    @Test func alertsOnceAfterAMinuteDown() throws {
        var monitor = ServerDownMonitor()
        let counts = try Self.feed(
            Array(repeating: Self.DOWN, count: 4),
            to: &monitor
        )
        #expect(counts == [0, 0, 0, 0])
        let alerts = monitor.evaluate(
            try Self.makeOverview(Self.DOWN),
            at: Self.START.addingTimeInterval(60)
        )
        #expect(alerts.map(\.identifier) == ["server.web-1"])
        let later_Alerts = monitor.evaluate(
            try Self.makeOverview(Self.DOWN),
            at: Self.START.addingTimeInterval(2_000)
        )
        #expect(later_Alerts.isEmpty)
    }

    @Test func shortOutageDoesNotAlert() throws {
        var monitor = ServerDownMonitor()
        let up = RemoteHostState.available(
            status: RemoteHostStatus(
                snapshot: try RemoteProbeTests.readSnapshot(
                    "probe-linux-1.txt"
                )
            )
        )
        let counts = try Self.feed(
            [Self.DOWN, Self.DOWN, Self.DOWN, up, Self.DOWN],
            to: &monitor
        )
        #expect(counts == [0, 0, 0, 0, 0])
    }

    @Test func setupProblemsNeverAlert() throws {
        var monitor = ServerDownMonitor()
        let refused = RemoteHostState.failed(
            problem: .authentication_Failed
        )
        let counts = try Self.feed(
            Array(repeating: refused, count: 8),
            to: &monitor
        )
        #expect(counts.allSatisfy { $0 == 0 })
    }

    @Test func messageNamesHostAndReason() throws {
        let alert = ServerDownAlert(
            host: try RemoteSamples.makeHost("db-1"),
            reason: "No route to host"
        )
        #expect(alert.message.title == "db-1 stopped responding")
        #expect(
            alert.message.body
                == "No route to host · no answer for 1 min"
        )
    }
}
