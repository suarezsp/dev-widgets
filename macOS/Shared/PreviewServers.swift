import DevWidgetsCore
import Foundation

/// Plausible servers for the widget gallery and Xcode previews.
extension PreviewData {
    static let SERVERS = makeServers()

    /// Alias and CPU share; nil CPU is a host that refused the key.
    static let PREVIEW_HOSTS: [(alias: String, cpu: Double?)] = [
        ("web-1", 0.18), ("db-1", nil), ("web-2", 0.64),
        ("ci-runner", 0.91), ("cache-1", 0.07), ("staging", 0.33),
    ]

    static func makeServers() -> ServerOverview {
        ServerOverview(
            reports: PREVIEW_HOSTS.compactMap { alias, cpu in
                RemoteHost(alias: alias).map {
                    RemoteHostReport(host: $0, state: makeState(cpu))
                }
            }
        )
    }

    static func makeState(_ cpu_Fraction: Double?) -> RemoteHostState
    {
        guard let cpu_Fraction else {
            return .failed(problem: .authentication_Failed)
        }
        var status = RemoteHostStatus(snapshot: makeServerSnapshot())
        status.cpu_Fraction = cpu_Fraction
        return .available(status: status)
    }

    static func makeServerSnapshot() -> RemoteSnapshot {
        let ticks = CPUTicks(busy_Ticks: 10, idle_Ticks: 90)
        var snapshot = RemoteSnapshot(
            cpu: CPUSample(total: ticks, cores: [ticks, ticks]),
            memory: MemoryUsage(
                physical: Capacity(
                    used_Bytes: 3 << 30,
                    total_Bytes: 8 << 30
                ),
                swap: Capacity(used_Bytes: 0, total_Bytes: 0),
                pressure: .normal
            ),
            disk_Space: Capacity(used_Bytes: 40, total_Bytes: 100)
        )
        snapshot.load_Average = LoadAverage(
            one_Minute: 0.42,
            five_Minutes: 0.37,
            fifteen_Minutes: 0.30
        )
        snapshot.uptime_Seconds = 3 * 86_400
        return snapshot
    }
}
