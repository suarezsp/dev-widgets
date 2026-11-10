import Foundation

/// When to ask GitHub again: once per interval (a minute for the
/// branch), at once when what is asked changes (project, branch),
/// and not before a rate limit resets.
public struct GitHubSchedule: Sendable {
    public static let INTERVAL_SECONDS = 60.0
    /// Wait used when GitHub limits us without saying until when.
    public static let UNKNOWN_RESET_SECONDS = 600.0

    public let interval_Seconds: Double
    private(set) var next_Date: Date?
    private(set) var last_Key: String?

    public init(interval_Seconds: Double = INTERVAL_SECONDS) {
        self.interval_Seconds = interval_Seconds
    }

    /// What a GitHub answer depends on: remote and branch.
    public static func makeKey(git: GitState) -> String {
        guard case .available(let status) = git else { return "" }
        return [status.remote_URL ?? "", status.branch.name ?? ""]
            .joined(separator: "#")
    }

    public func isDue(key: String, at now: Date) -> Bool {
        guard key == last_Key, let next_Date else { return true }
        return now >= next_Date
    }

    public mutating func record(
        _ state: GitHubState,
        key: String,
        at now: Date
    ) {
        last_Key = key
        let regular_Date = now.addingTimeInterval(interval_Seconds)
        guard case .rate_Limited(let reset_At) = state else {
            next_Date = regular_Date
            return
        }
        let reset_Date =
            reset_At
            ?? now.addingTimeInterval(Self.UNKNOWN_RESET_SECONDS)
        next_Date = max(reset_Date, regular_Date)
    }
}
