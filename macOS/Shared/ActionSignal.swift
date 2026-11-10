import Foundation
import notify

/// Wakes the menu bar app when a widget queued an action. Darwin
/// notifications carry no data and cross the extension sandbox;
/// the action itself waits in the App Group's `ActionInbox`.
enum ActionSignal {
    static let NAME = "com.morsetechnologies.devwidgets.action"

    static func post() {
        notify_post(NAME)
    }

    /// Calls `handler` on the main queue after every post. Keep the
    /// returned token alive as long as the app wants the signal.
    static func observe(
        _ handler: @escaping @MainActor () -> Void
    ) -> Int32 {
        var token: Int32 = 0
        notify_register_dispatch(NAME, &token, .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        return token
    }
}
