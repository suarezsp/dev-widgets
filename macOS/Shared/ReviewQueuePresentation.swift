import DevWidgetsCore
import Foundation

/// The "awaiting your review" line and its rows.
public enum ReviewQueuePresentation {
    public static func describe(
        _ state: ReviewQueueState
    ) -> ContextLine {
        switch state {
        case .not_Loaded:
            ContextLine(title: "Reviews", detail_Text: "Checking…")
        case .failed(let problem):
            GitHubPresentation.describe(problem).renamed("Reviews")
        case .available(let queue):
            describeQueue(queue)
        }
    }

    /// Amber while someone waits on the user.
    public static func describeQueue(
        _ queue: ReviewQueue
    ) -> ContextLine {
        guard queue.total_Count > 0 else {
            return ContextLine(
                title: "Reviews",
                detail_Text: "Nothing awaits your review"
            )
        }
        let noun = queue.total_Count == 1 ? "request" : "requests"
        return ContextLine(
            title: "Reviews",
            detail_Text: "\(queue.total_Count) \(noun) await you",
            level: .elevated
        )
    }

    /// "swift-format #1322" over the title.
    public static func describeRequest(
        _ request: ReviewRequest
    ) -> ContextLine {
        ContextLine(
            title: "\(request.repository.name) #\(request.number)",
            detail_Text: request.title
        )
    }

    public static func listRequests(
        _ state: ReviewQueueState,
        limit: Int
    ) -> [ReviewRequest] {
        guard case .available(let queue) = state else { return [] }
        return Array(queue.requests.prefix(limit))
    }
}

extension ContextLine {
    /// The same detail and level under another headline.
    public func renamed(_ new_Title: String) -> ContextLine {
        ContextLine(
            title: new_Title,
            detail_Text: detail_Text,
            level: level
        )
    }
}
