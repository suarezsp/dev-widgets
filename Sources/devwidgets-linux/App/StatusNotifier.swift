import CGtk
import DevWidgetsLinuxShell
import Glibc

/// The tray icon as a StatusNotifierItem on the session bus. It
/// appears only where a watcher runs (KDE, XFCE, LXQt, Budgie, or
/// GNOME with the AppIndicator extension); `on_Registered` tells
/// the app, which then hides the window on close instead of
/// quitting.
final class StatusNotifier {
    typealias Text = UnsafePointer<CChar>?

    private static let METHOD_CALL:
        @convention(c) (
            OpaquePointer?, Text, Text, Text, Text, OpaquePointer?,
            OpaquePointer?, UnsafeMutableRawPointer?
        ) -> Void = { _, _, _, _, method_Name, _, invocation, data in
            let notifier = StatusNotifier.take(data)
            let name = method_Name.map { String(cString: $0) } ?? ""
            if ["Activate", "SecondaryActivate"].contains(name) {
                notifier?.on_Activate()
            }
            g_dbus_method_invocation_return_value(invocation, nil)
        }

    private static let GET_PROPERTY:
        @convention(c) (
            OpaquePointer?, Text, Text, Text, Text,
            UnsafeMutablePointer<UnsafeMutablePointer<GError>?>?,
            UnsafeMutableRawPointer?
        ) -> OpaquePointer? = { _, _, _, _, property_Name, _, data in
            readProperty(property_Name, data)
        }

    private static func readProperty(
        _ property_Name: Text,
        _ data: UnsafeMutableRawPointer?
    ) -> OpaquePointer? {
        guard let notifier = take(data), let property_Name else {
            return nil
        }
        let value = notifier.properties.value(
            named: String(cString: property_Name),
            state: notifier.state
        )
        return value.flatMap { TrayVariants.make($0) }
    }

    private static let WATCHER_APPEARED:
        @convention(c) (
            OpaquePointer?, Text, Text, UnsafeMutableRawPointer?
        ) -> Void = { _, _, _, data in
            StatusNotifier.take(data)?.register()
        }

    private let on_Activate: () -> Void
    var on_Registered: () -> Void = {}
    private let properties: TrayProperties
    private var state = TrayState.STARTING
    private var connection: OpaquePointer?
    private let bus_Name = StatusNotifierProtocol.makeBusName(
        process_ID: getpid()
    )
    private var vtable = GDBusInterfaceVTable(
        method_call: METHOD_CALL,
        get_property: GET_PROPERTY,
        set_property: nil,
        padding: (nil, nil, nil, nil, nil, nil, nil, nil)
    )

    init(
        properties: TrayProperties,
        on_Activate: @escaping () -> Void
    ) {
        self.properties = properties
        self.on_Activate = on_Activate
    }

    private static func take(
        _ data: UnsafeMutableRawPointer?
    ) -> StatusNotifier? {
        data.map {
            Unmanaged<StatusNotifier>.fromOpaque($0)
                .takeUnretainedValue()
        }
    }

    /// Exports the item and waits for a watcher. Lives as long as
    /// the app, so the pointer GLib keeps is never released.
    func start() {
        connection = g_bus_get_sync(G_BUS_TYPE_SESSION, nil, nil)
        guard let connection, exportObject(connection) else { return }
        g_bus_own_name_on_connection(
            connection,
            bus_Name,
            G_BUS_NAME_OWNER_FLAGS_NONE,
            nil,
            nil,
            nil,
            nil
        )
        g_bus_watch_name_on_connection(
            connection,
            StatusNotifierProtocol.WATCHER_NAME,
            G_BUS_NAME_WATCHER_FLAGS_NONE,
            Self.WATCHER_APPEARED,
            nil,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }

    private func exportObject(_ connection: OpaquePointer) -> Bool {
        let node_Info = g_dbus_node_info_new_for_xml(
            StatusNotifierProtocol.INTROSPECTION_XML,
            nil
        )
        guard let node_Info,
            let interface_Info = g_dbus_node_info_lookup_interface(
                node_Info,
                StatusNotifierProtocol.ITEM_INTERFACE
            )
        else { return false }
        let object_ID = g_dbus_connection_register_object(
            connection,
            StatusNotifierProtocol.ITEM_PATH,
            interface_Info,
            &vtable,
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
        return object_ID != 0
    }

    private func register() {
        let parameters = g_variant_new_tuple(
            [g_variant_new_string(bus_Name)],
            1
        )
        g_dbus_connection_call(
            connection,
            StatusNotifierProtocol.WATCHER_NAME,
            StatusNotifierProtocol.WATCHER_PATH,
            StatusNotifierProtocol.WATCHER_NAME,
            StatusNotifierProtocol.REGISTER_METHOD,
            parameters,
            nil,
            G_DBUS_CALL_FLAGS_NONE,
            -1,
            nil,
            nil,
            nil
        )
        on_Registered()
    }

    /// Tells the panel when the tooltip or the status changed.
    func update(_ new_State: TrayState) {
        guard new_State != state else { return }
        let status_Changed =
            new_State.status_Text != state.status_Text
        state = new_State
        emitSignal("NewToolTip", parameters: nil)
        if status_Changed {
            emitSignal(
                "NewStatus",
                parameters: g_variant_new_tuple(
                    [g_variant_new_string(state.status_Text)],
                    1
                )
            )
        }
    }

    private func emitSignal(
        _ name: String,
        parameters: OpaquePointer?
    ) {
        guard let connection else { return }
        g_dbus_connection_emit_signal(
            connection,
            nil,
            StatusNotifierProtocol.ITEM_PATH,
            StatusNotifierProtocol.ITEM_INTERFACE,
            name,
            parameters,
            nil
        )
    }
}

/// GVariants for the property values (g_variant_new is variadic,
/// so tuples and arrays are built piece by piece).
enum TrayVariants {
    static func make(_ value: TrayPropertyValue) -> OpaquePointer? {
        switch value {
        case .text(let text): g_variant_new_string(text)
        case .flag(let flag): g_variant_new_boolean(flag ? 1 : 0)
        case .tooltip(let title, let body): makeTooltip(title, body)
        }
    }

    static func makeTooltip(
        _ title: String,
        _ body: String
    ) -> OpaquePointer? {
        let pixmap_Type = g_variant_type_new("(iiay)")
        defer { g_variant_type_free(pixmap_Type) }
        let children: [OpaquePointer?] = [
            g_variant_new_string(""),
            g_variant_new_array(pixmap_Type, nil, 0),
            g_variant_new_string(title),
            g_variant_new_string(body),
        ]
        return g_variant_new_tuple(children, 4)
    }
}
