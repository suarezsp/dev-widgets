import DevWidgetsCore
import Foundation

/// One desktop notification, whatever raised it. The identifier
/// makes a new one replace the previous of the same kind.
public struct DesktopNotification: Equatable, Sendable {
    public let identifier: String
    public let message: AlertMessage
    /// Opened when the notification is clicked (the failed run).
    public var page_URL: URL?

    public init(identifier: String, message: AlertMessage) {
        self.identifier = identifier
        self.message = message
    }
}

/// Every alert source of the Linux app behind one door, with the
/// same debounce as the Mac: threshold alerts on each sample,
/// failed CI after each context refresh, unreachable servers after
/// each poll. Monitors always run; the settings only decide what
/// is shown, so turning a switch on does not replay old events.
public struct AlertRouter: Sendable {
    private var alert_Monitor = AlertMonitor()
    private var server_Monitor = ServerDownMonitor()

    public init() {}

    public mutating func route(
        _ snapshot: MetricSnapshot,
        settings: AlertSettings
    ) -> [DesktopNotification] {
        alert_Monitor.evaluate(
            snapshot.readings,
            settings: settings,
            at: snapshot.captured_At
        ).map { alert in
            DesktopNotification(
                identifier: "alert.\(alert.rule.metric.rawValue)",
                message: AlertMessage(
                    alert: alert,
                    settings: settings
                )
            )
        }
    }

    public func route(
        _ ci_Alert: CIFailureAlert?,
        settings: AlertSettings
    ) -> [DesktopNotification] {
        guard settings.notifies_CI_Failure, let ci_Alert else {
            return []
        }
        var notification = DesktopNotification(
            identifier: ci_Alert.identifier,
            message: ci_Alert.message
        )
        notification.page_URL = ci_Alert.page_URL
        return [notification]
    }

    public mutating func route(
        _ overview: ServerOverview,
        settings: AlertSettings
    ) -> [DesktopNotification] {
        let alerts = server_Monitor.evaluate(
            overview,
            at: overview.captured_At
        )
        guard settings.notifies_Server_Down else { return [] }
        return alerts.map {
            DesktopNotification(
                identifier: $0.identifier,
                message: $0.message
            )
        }
    }
}
