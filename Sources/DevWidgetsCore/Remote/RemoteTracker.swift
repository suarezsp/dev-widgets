import Foundation

/// Turns polls into statuses: CPU and network need the previous
/// poll of the same host, so the first one shows load only.
public struct RemoteTracker: Sendable {
    public static let INTERVAL_SECONDS = 15.0

    private var previous_Snapshots: [RemoteHost: RemoteSnapshot] = [:]

    public init() {}

    public mutating func update(
        hosts: [RemoteHost],
        results: [RemoteHost: Result<RemoteSnapshot, RemoteProblem>]
    ) -> ServerOverview {
        let reports = hosts.map { host in
            RemoteHostReport(
                host: host,
                state: makeState(host, result: results[host])
            )
        }
        previous_Snapshots = previous_Snapshots.filter {
            hosts.contains($0.key)
        }
        return ServerOverview(reports: reports)
    }

    private mutating func makeState(
        _ host: RemoteHost,
        result: Result<RemoteSnapshot, RemoteProblem>?
    ) -> RemoteHostState {
        switch result {
        case nil: return .not_Loaded
        case .failure(let problem):
            previous_Snapshots[host] = nil
            return .failed(problem: problem)
        case .success(let snapshot):
            defer { previous_Snapshots[host] = snapshot }
            return .available(
                status: Self.makeStatus(
                    snapshot,
                    previous: previous_Snapshots[host]
                )
            )
        }
    }

    static func makeStatus(
        _ snapshot: RemoteSnapshot,
        previous: RemoteSnapshot?
    ) -> RemoteHostStatus {
        var status = RemoteHostStatus(snapshot: snapshot)
        guard let previous else { return status }
        let elapsed_Seconds = snapshot.captured_At.timeIntervalSince(
            previous.captured_At
        )
        guard elapsed_Seconds > 0 else { return status }
        status.cpu_Fraction = snapshot.cpu.total.busyFraction(
            since: previous.cpu.total
        )
        status.network = NetworkThroughput(
            from: previous.network,
            to: snapshot.network,
            elapsed_Seconds: elapsed_Seconds
        )
        return status
    }
}
