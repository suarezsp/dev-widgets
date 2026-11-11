import CGtk
import DevWidgetsLinuxShell

/// The tray icon's right-click menu as a com.canonical.dbusmenu
/// object next to the StatusNotifierItem. The menu is fixed, so
/// every layout request gets the same tree.
final class TrayMenu {
    typealias Text = UnsafePointer<CChar>?

    private static let METHOD_CALL:
        @convention(c) (
            OpaquePointer?, Text, Text, Text, Text, OpaquePointer?,
            OpaquePointer?, UnsafeMutableRawPointer?
        ) -> Void = {
            _,
            _,
            _,
            _,
            method_Name,
            arguments,
            call,
            data in
            let name = method_Name.map { String(cString: $0) } ?? ""
            let reply = TrayMenu.take(data)?.answer(name, arguments)
            g_dbus_method_invocation_return_value(call, reply)
        }

    private static let GET_PROPERTY:
        @convention(c) (
            OpaquePointer?, Text, Text, Text, Text,
            UnsafeMutablePointer<UnsafeMutablePointer<GError>?>?,
            UnsafeMutableRawPointer?
        ) -> OpaquePointer? = { _, _, _, _, property_Name, _, _ in
            property_Name
                .flatMap {
                    DBusMenuProtocol.value(named: String(cString: $0))
                }
                .flatMap { TrayVariants.make($0) }
        }

    private let on_Click: (TrayMenuItem) -> Void
    private var vtable = GDBusInterfaceVTable(
        method_call: METHOD_CALL,
        get_property: GET_PROPERTY,
        set_property: nil,
        padding: (nil, nil, nil, nil, nil, nil, nil, nil)
    )

    init(on_Click: @escaping (TrayMenuItem) -> Void) {
        self.on_Click = on_Click
    }

    private static func take(
        _ data: UnsafeMutableRawPointer?
    ) -> TrayMenu? {
        data.map {
            Unmanaged<TrayMenu>.fromOpaque($0).takeUnretainedValue()
        }
    }

    /// Lives as long as the app, like the StatusNotifier that
    /// exports it, so the pointer GLib keeps is never released.
    func export(on connection: OpaquePointer) {
        let node_Info = g_dbus_node_info_new_for_xml(
            DBusMenuProtocol.INTROSPECTION_XML,
            nil
        )
        guard let node_Info,
            let interface_Info = g_dbus_node_info_lookup_interface(
                node_Info,
                DBusMenuProtocol.INTERFACE
            )
        else { return }
        g_dbus_connection_register_object(
            connection,
            DBusMenuProtocol.MENU_PATH,
            interface_Info,
            &vtable,
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    /// The reply tuple for each dbusmenu method.
    private func answer(
        _ method_Name: String,
        _ arguments: OpaquePointer?
    ) -> OpaquePointer? {
        typealias Menu = TrayMenuVariants
        switch method_Name {
        case "GetLayout": return Menu.makeLayoutReply(arguments)
        case "GetGroupProperties":
            return Menu.makeGroupReply(arguments)
        case "GetProperty": return Menu.makePropertyReply(arguments)
        case "Event": handleEvent(arguments)
        case "EventGroup": handleEventGroup(arguments)
        case "AboutToShow":
            return g_variant_new_tuple([g_variant_new_boolean(0)], 1)
        default: break
        }
        return Menu.makeEmptyListsReply(
            count: method_Name == "AboutToShowGroup" ? 2 : 1,
            is_Needed: method_Name != "Event"
        )
    }

    /// Event and EventGroup entries both start with (is...).
    private func handleEvent(_ event: OpaquePointer?) {
        let clicked_Item = TrayMenuItem.findClicked(
            id: VariantReading.readInt32(event, 0),
            event_ID: VariantReading.readString(event, 1)
        )
        clicked_Item.map(on_Click)
    }

    private func handleEventGroup(_ arguments: OpaquePointer?) {
        VariantReading.forEachChild(arguments, 0) {
            handleEvent($0)
        }
    }
}
