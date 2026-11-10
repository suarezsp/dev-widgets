import Foundation

/// An action tapped once and waiting for its confirming tap.
public struct ArmedAction: Codable, Equatable, Sendable {
    public let action: WidgetAction
    public let armed_At: Date
}

/// Widgets cannot show dialogs, so a destructive button asks for
/// a second tap: the first arms it (the widget then shows
/// "Confirm"), a second tap within the window performs it.
public struct ConfirmationGate: Sendable {
    public static let FILE_NAME = "armed-action.json"
    public static let WINDOW_SECONDS = 8.0

    let store: JSONFileStore<ArmedAction>

    public init(container_URL: URL) {
        store = JSONFileStore(
            directory: container_URL,
            file_Name: Self.FILE_NAME
        )
    }

    /// True when this tap confirms an armed action.
    public func confirm(
        _ action: WidgetAction,
        at now: Date = Date()
    ) throws -> Bool {
        guard action.needs_Confirmation else { return true }
        if readArmedAction(at: now) == action {
            store.remove()
            return true
        }
        try store.save(ArmedAction(action: action, armed_At: now))
        return false
    }

    /// The action waiting for confirmation, if still in time.
    public func readArmedAction(
        at now: Date = Date()
    ) -> WidgetAction? {
        guard let armed = try? store.load(),
            now.timeIntervalSince(armed.armed_At)
                <= Self.WINDOW_SECONDS
        else { return nil }
        return armed.action
    }
}
