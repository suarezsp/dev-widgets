import Foundation

/// One "server stopped responding" notification.
public struct ServerDownAlert: Equatable, Sendable {
    public let host: RemoteHost
    /// ssh's own words: "Connection refused", "No route to host".
    public let reason: String

    /// One notification per server, replaced if it fires again.
    public var identifier: String { "server.\(host.alias)" }

    /// "web-1 stopped responding" / "Connection refused · no answer
    /// for 1 min".
    public var message: AlertMessage {
        let minutes = Int(
            ServerDownMonitor.TIMING.sustain_Seconds / 60
        )
        return AlertMessage(
            title: String(
                localized: "\(host.alias) stopped responding"
            ),
            body: String(
                localized: "\(reason) · no answer for \(minutes) min"
            )
        )
    }
}

/// Notifies when a monitored server stays unreachable, with the
/// threshold alerts' debounce (`AlertTracker`), one per host.
public struct ServerDownMonitor: Sendable {
    /// Four polls in a row (one every 15 s) must fail: a reboot or
    /// a Wi-Fi hiccup does not notify. One notification per host
    /// every 15 minutes at most.
    public static let TIMING = AlertTiming(
        sustain_Seconds: 60,
        cooldown_Seconds: 900
    )

    private var trackers: [RemoteHost: AlertTracker] = [:]

    public init() {}

    public mutating func evaluate(
        _ overview: ServerOverview,
        at now: Date
    ) -> [ServerDownAlert] {
        let hosts = overview.reports.map(\.host)
        trackers = trackers.filter { hosts.contains($0.key) }
        return overview.reports.compactMap { report in
            var tracker = trackers[report.host] ?? AlertTracker()
            defer { trackers[report.host] = tracker }
            let should_Notify = tracker.update(
                Self.classify(report.state),
                at: now,
                timing: Self.TIMING
            )
            guard should_Notify,
                case .failed(.unreachable(let reason)) = report.state
            else { return nil }
            return ServerDownAlert(host: report.host, reason: reason)
        }
    }

    /// Only "unreachable" means down. A refused key, an unknown
    /// host key or a non-Linux host is a setup problem the row
    /// already shows; it neither alerts nor re-arms.
    static func classify(_ state: RemoteHostState) -> AlertCondition {
        switch state {
        case .available: .recovered
        case .failed(.unreachable): .breached
        case .failed, .not_Loaded: .between
        }
    }
}
