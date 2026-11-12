import CGtk
import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// The confirmation before a destructive action, and the project
/// folder chooser.
enum Dialogs {
    static let CONFIRM_RESPONSE = "confirm"
    static let CANCEL_RESPONSE = "cancel"

    private static let FOLDER_CHOSEN: GAsyncReadyCallback = {
        source,
        result,
        data in
        guard let data else { return }
        let box = Unmanaged<ValueBox<URL?>>.fromOpaque(data)
            .takeRetainedValue()
        let folder = gtk_file_dialog_select_folder_finish(
            castPointer(source),
            result,
            nil
        )
        box.action(Self.readPath(folder))
    }

    private static func readPath(_ folder: OpaquePointer?) -> URL? {
        guard let folder else { return nil }
        defer { g_object_unref(UnsafeMutableRawPointer(folder)) }
        guard let path = g_file_get_path(folder) else { return nil }
        defer { g_free(path) }
        return URL(fileURLWithPath: String(cString: path))
    }

    /// Asks once more; `confirmed` runs only on the red button.
    static func confirm(
        _ action: WidgetAction,
        parent: WidgetPointer,
        confirmed: @escaping () -> Void
    ) {
        let dialog = makeAlert(action)
        Signals.connectString(
            UnsafeMutableRawPointer(dialog),
            "response"
        ) { response in
            if response == CONFIRM_RESPONSE { confirmed() }
        }
        adw_dialog_present(castPointer(dialog), parent)
    }

    /// Cancel is the default and Escape; the action is red.
    private static func makeAlert(
        _ action: WidgetAction
    ) -> UnsafeMutablePointer<AdwAlertDialog> {
        let alert: UnsafeMutablePointer<AdwAlertDialog> = castPointer(
            adw_alert_dialog_new(
                String(localized: "\(action.title)?"),
                action.consequence_Text
            )
        )
        for (response, label) in [
            (CANCEL_RESPONSE, String(localized: "Cancel")),
            (CONFIRM_RESPONSE, action.title),
        ] {
            adw_alert_dialog_add_response(alert, response, label)
        }
        adw_alert_dialog_set_response_appearance(
            alert,
            CONFIRM_RESPONSE,
            ADW_RESPONSE_DESTRUCTIVE
        )
        adw_alert_dialog_set_default_response(alert, CANCEL_RESPONSE)
        adw_alert_dialog_set_close_response(alert, CANCEL_RESPONSE)
        return alert
    }

    /// nil when the user cancels.
    static func chooseFolder(
        parent: WidgetPointer,
        chosen: @escaping (URL?) -> Void
    ) {
        let dialog = gtk_file_dialog_new()
        gtk_file_dialog_set_title(
            dialog,
            String(localized: "Choose project folder")
        )
        gtk_file_dialog_select_folder(
            dialog,
            castPointer(parent),
            nil,
            FOLDER_CHOSEN,
            ValueBox<URL?>(chosen).retainedPointer()
        )
    }
}
