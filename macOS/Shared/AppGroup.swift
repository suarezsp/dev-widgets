import DevWidgetsCore
import Foundation

/// Where the menu bar app and the widget extension meet.
enum AppGroup {
    /// Info.plist key both targets get from the build setting
    /// `APP_GROUP_IDENTIFIER` ("TEAMID.com.morsetechnologies...").
    static let INFO_KEY = "DevWidgetsAppGroup"
    /// nil without the key, e.g. in the image renderer.
    static let IDENTIFIER =
        Bundle.main.object(forInfoDictionaryKey: INFO_KEY) as? String
    static let WIDGET_KIND = "com.morsetechnologies.devwidgets.metric"
    static let DASHBOARD_KIND =
        "com.morsetechnologies.devwidgets.dashboard"

    static let CONTEXT_KIND =
        "com.morsetechnologies.devwidgets.context"
    static let SERVERS_KIND =
        "com.morsetechnologies.devwidgets.servers"

    /// nil when the App Group is not configured.
    static func makeSnapshotStore() -> SnapshotStore? {
        containerURL().map { SnapshotStore(directory: $0) }
    }

    static func makeContextStore() -> ContextStore? {
        containerURL().map { ContextStore(directory: $0) }
    }

    static func makeServerStore() -> ServerStore? {
        containerURL().map { ServerStore(directory: $0) }
    }

    static func makeActionInbox() -> ActionInbox? {
        containerURL().map { ActionInbox(container_URL: $0) }
    }

    static func makeConfirmationGate() -> ConfirmationGate? {
        containerURL().map { ConfirmationGate(container_URL: $0) }
    }

    static func containerURL() -> URL? {
        IDENTIFIER.flatMap {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: $0
            )
        }
    }
}
