import AppKit
import DevWidgetsCore
import Foundation
import UserNotifications

/// Posts threshold alerts, failed-CI alerts and action results. One
/// identifier per metric (or branch), so a new alert replaces the
/// old one in Notification Center instead of piling up.
@MainActor
final class UserNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let SHARED = UserNotifier()
    nonisolated static let PAGE_KEY = "pageURL"

    private var center: UNUserNotificationCenter { .current() }

    /// Asks once; macOS remembers the answer.
    func requestAuthorization() async {
        center.delegate = self
        _ = try? await center.requestAuthorization(
            options: [.alert, .sound]
        )
    }

    /// A click on a notification with a page opens it (the failed
    /// run for CI).
    func post(
        _ message: AlertMessage,
        identifier: String,
        page_URL: URL? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.threadIdentifier = "devwidgets"
        if let page_URL {
            content.userInfo = [
                Self.PAGE_KEY: page_URL.absoluteString
            ]
        }
        center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
        )
    }

    /// Shows banners even while the menu bar panel is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let user_Info = response.notification.request.content.userInfo
        guard let page_Text = user_Info[Self.PAGE_KEY] as? String,
            let page_URL = URL(string: page_Text)
        else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(page_URL) }
    }
}
