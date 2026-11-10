import CGtk
import DevWidgetsLinuxShell
import Foundation

/// Opens pages and folders with the desktop's default handler.
enum URLOpener {
    static func open(_ url: URL) {
        g_app_info_launch_default_for_uri(
            url.absoluteString,
            nil,
            nil
        )
    }
}

/// Desktop notifications through GNotification: the portal or
/// GNOME Shell when present, else freedesktop notifications
/// (dunst, mako, KDE, XFCE). The identifier makes a new alert of
/// the same kind replace the previous one.
final class DesktopNotifier {
    static let OPEN_URL_ACTION = "open-url"
    static let SHOW_ACTION = "show-dashboard"

    private let application: OpaquePointer

    init(
        application: OpaquePointer,
        show_Dashboard: @escaping () -> Void
    ) {
        self.application = application
        addAction(Self.OPEN_URL_ACTION, parameter_Type: true) {
            variant in
            guard let variant,
                let text = g_variant_get_string(variant, nil),
                let url = URL(string: String(cString: text))
            else { return }
            URLOpener.open(url)
        }
        addAction(Self.SHOW_ACTION, parameter_Type: false) { _ in
            show_Dashboard()
        }
    }

    private func addAction(
        _ name: String,
        parameter_Type has_Parameter: Bool,
        _ handler: @escaping (OpaquePointer?) -> Void
    ) {
        let action = g_simple_action_new(
            name,
            has_Parameter ? dw_string_variant_type() : nil
        )
        Signals.connectVariant(
            UnsafeMutableRawPointer(action),
            "activate",
            handler
        )
        g_action_map_add_action(
            castPointer(application),
            castPointer(action)
        )
    }

    func send(_ alert: DesktopNotification) {
        let notification = g_notification_new(alert.message.title)
        g_notification_set_body(notification, alert.message.body)
        let icon = g_themed_icon_new(LinuxApp.APPLICATION_ID)
        g_notification_set_icon(notification, icon)
        g_object_unref(UnsafeMutableRawPointer(icon))
        if let page_URL = alert.page_URL {
            g_notification_set_default_action_and_target_value(
                notification,
                "app.\(Self.OPEN_URL_ACTION)",
                g_variant_new_string(page_URL.absoluteString)
            )
        } else {
            g_notification_set_default_action(
                notification,
                "app.\(Self.SHOW_ACTION)"
            )
        }
        g_application_send_notification(
            castPointer(application),
            alert.identifier,
            notification
        )
        g_object_unref(UnsafeMutableRawPointer(notification))
    }
}
