import DevWidgetsCore
import Foundation

/// One bar of a server row: CPU, memory or disk.
public struct ServerGauge: Equatable {
    public let title: String
    /// nil until a second poll gives CPU.
    public let fraction: Double?

    public var level: LoadLevel {
        fraction.map(LoadThresholds.DEFAULT.level) ?? .normal
    }

    /// "12%", or "—" while unknown.
    public var value_Text: String {
        fraction.map(MetricFormatting.describePercent) ?? "—"
    }
}

/// What the panel and the servers widget show for one host.
public struct ServerLine: Equatable {
    public let alias: String
    public let detail_Text: String
    public var level = LoadLevel.normal
    public var gauges: [ServerGauge] = []
}

public enum ServerPresentation {
    public static func describe(
        _ report: RemoteHostReport
    ) -> ServerLine {
        let alias = report.host.alias
        switch report.state {
        case .not_Loaded:
            return ServerLine(
                alias: alias,
                detail_Text: String(localized: "Connecting…")
            )
        case .failed(let problem):
            return ServerLine(
                alias: alias,
                detail_Text: describeProblem(problem),
                level: .critical
            )
        case .available(let status):
            return describeStatus(status, alias: alias)
        }
    }

    /// The worst gauge colours the row.
    public static func describeStatus(
        _ status: RemoteHostStatus,
        alias: String
    ) -> ServerLine {
        let gauges = makeGauges(status)
        let levels = gauges.map(\.level)
        let worst_Level = LoadLevel.allCases.last(
            where: levels.contains
        )
        return ServerLine(
            alias: alias,
            detail_Text: describeDetail(status),
            level: worst_Level ?? .normal,
            gauges: gauges
        )
    }

    public static func makeGauges(
        _ status: RemoteHostStatus
    ) -> [ServerGauge] {
        let snapshot = status.snapshot
        return [
            ServerGauge(title: "CPU", fraction: status.cpu_Fraction),
            ServerGauge(
                title: String(localized: "Memory"),
                fraction: snapshot.memory.physical.used_Fraction
            ),
            ServerGauge(
                title: String(localized: "Disk"),
                fraction: snapshot.disk_Space.used_Fraction
            ),
        ]
    }

    /// "8 cores · load 0.21 · up 3 d".
    public static func describeDetail(
        _ status: RemoteHostStatus
    ) -> String {
        var parts = [String(localized: "\(status.core_Count) cores")]
        if let load_Average = status.snapshot.load_Average {
            let load_Text = String(
                format: "%.2f",
                load_Average.one_Minute
            )
            parts.append(String(localized: "load \(load_Text)"))
        }
        if let uptime_Seconds = status.snapshot.uptime_Seconds {
            let uptime_Text = describeUptime(uptime_Seconds)
            parts.append(String(localized: "up \(uptime_Text)"))
        }
        return parts.joined(separator: " · ")
    }

    public static func describeUptime(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        return hours < 48 ? "\(hours) h" : "\(hours / 24) d"
    }

    /// Each problem says what to do about it.
    public static func describeProblem(
        _ problem: RemoteProblem
    ) -> String {
        switch problem {
        case .ssh_Missing: String(localized: "ssh not found")
        case .host_Key_Rejected:
            String(
                localized:
                    "Unknown host key: connect once in Terminal"
            )
        case .authentication_Failed:
            String(localized: "Key refused: is it in ssh-agent?")
        case .interactive_Login_Required:
            String(
                localized:
                    "Asks for a password or 2FA: use a key-only login"
            )
        case .unreachable(let reason): reason
        case .not_Linux(let system):
            String(localized: "\(system) is not supported yet")
        }
    }
}
