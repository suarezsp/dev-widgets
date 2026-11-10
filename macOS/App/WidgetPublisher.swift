import DevWidgetsCore
import Foundation
import OSLog
import WidgetKit

/// Saves snapshots to the App Group and asks WidgetKit to reload,
/// at most once per interval: WidgetKit budgets reloads, so asking
/// every second would only get requests dropped. A failure is
/// kept in `problem_Text` for the menu bar panel, not only logged.
struct WidgetPublisher {
    static let PUBLISH_INTERVAL_SECONDS: TimeInterval = 60
    static let MISSING_GROUP_TEXT =
        "Widgets can't update: the App Group is missing."
    static let SAVE_FAILED_TEXT =
        "Widgets can't update: saving to the App Group failed."
    static let LOGGER = Logger(
        subsystem: "com.morsetechnologies.devwidgets",
        category: "WidgetPublisher"
    )

    private let store: SnapshotStore?
    private var last_Publish_Date: Date?
    /// Why the widgets are not getting data; nil when they are.
    private(set) var problem_Text: String?

    init(store: SnapshotStore?) {
        self.store = store
        problem_Text = store == nil ? Self.MISSING_GROUP_TEXT : nil
    }

    mutating func publishIfDue(_ snapshot: MetricSnapshot) {
        guard let store, isDue(at: snapshot.captured_At) else {
            return
        }
        // Retried every interval: the cause may go away.
        last_Publish_Date = snapshot.captured_At
        do {
            try store.save(snapshot)
            problem_Text = nil
            Self.LOGGER.notice("Saved snapshot for the widgets")
        } catch {
            Self.LOGGER.error("Saving snapshot failed: \(error)")
            problem_Text = Self.SAVE_FAILED_TEXT
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func isDue(at capture_Date: Date) -> Bool {
        guard let last_Publish_Date else { return true }
        let elapsed_Seconds =
            capture_Date
            .timeIntervalSince(last_Publish_Date)
        return elapsed_Seconds >= Self.PUBLISH_INTERVAL_SECONDS
    }
}
