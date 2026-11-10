import Foundation

/// Decides when a widget should reload. WidgetKit budgets reloads,
/// and numbers change on every read, so only a change of `Shape`,
/// what changes the widget's meaning, counts, at most once per
/// interval.
public struct ReloadThrottle<Shape: Equatable & Sendable>: Sendable {
    public let min_Reload_Seconds: Double
    private var last_Shape: Shape?
    private var last_Reload_Date: Date?

    public init(min_Reload_Seconds: Double) {
        self.min_Reload_Seconds = min_Reload_Seconds
    }

    /// A change inside the minimum interval is not lost: the shape
    /// is only remembered once a reload is granted.
    public mutating func shouldReload(
        for shape: Shape,
        at now: Date
    ) -> Bool {
        guard shape != last_Shape else { return false }
        if let last_Reload_Date,
            now.timeIntervalSince(last_Reload_Date)
                < min_Reload_Seconds
        {
            return false
        }
        last_Shape = shape
        last_Reload_Date = now
        return true
    }
}

/// The parts of a context that change what the widget says: Git,
/// GitHub, the review queue, which containers run and which ports
/// are open (not container CPU).
public struct ContextShape: Equatable, Sendable {
    public static let MIN_RELOAD_SECONDS = 30.0

    let git: GitState
    let github: GitHubState
    let review_Queue: ReviewQueueState
    let running_Containers: [String]
    let port_Owners: [String]

    public init(_ context: DeveloperContext) {
        git = context.git
        github = context.github
        review_Queue = context.review_Queue
        running_Containers = context.docker.running_Containers
            .map(\.identity.name)
        port_Owners = context.ports.map {
            "\($0.port) \($0.owner?.name ?? "")"
        }
    }
}

/// The servers widget changes meaning when a host goes up or down
/// or one of its levels (green, amber, red) changes.
public struct ServerShape: Equatable, Sendable {
    public static let MIN_RELOAD_SECONDS = 60.0

    let host_Lines: [String]

    public init(_ overview: ServerOverview) {
        host_Lines = overview.reports.map(Self.describe)
    }

    static func describe(_ report: RemoteHostReport) -> String {
        guard case .available(let status) = report.state else {
            return "\(report.host.alias) \(report.state)"
        }
        let levels = [
            status.cpu_Fraction ?? 0,
            status.snapshot.memory.physical.used_Fraction,
            status.snapshot.disk_Space.used_Fraction,
        ].map { LoadThresholds.DEFAULT.level(for: $0).rawValue }
        return "\(report.host.alias) " + levels.joined(separator: ",")
    }
}
