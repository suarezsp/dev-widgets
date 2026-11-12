import DevWidgetsPresentation

/// The entries of the tray icon's right-click menu. The raw value
/// is the dbusmenu item id; 0 is the root, which holds them all.
public enum TrayMenuItem: Int32, CaseIterable, Sendable {
    case toggle_Window = 1
    case preferences
    case separator
    case quit

    /// The item's dbusmenu properties, by name.
    public var properties: [String: TrayPropertyValue] {
        switch self {
        case .toggle_Window:
            [
                "label": .text(
                    String(localized: "Show or Hide Dashboard")
                )
            ]
        case .preferences:
            ["label": .text(String(localized: "Preferences…"))]
        case .separator: ["type": .text("separator")]
        case .quit:
            ["label": .text(String(localized: "Quit DevWidgets"))]
        }
    }

    /// The item a dbusmenu "Event" asks for, if it is a click on
    /// an item that does something.
    public static func findClicked(
        id: Int32,
        event_ID: String
    ) -> TrayMenuItem? {
        guard event_ID == "clicked",
            let item = TrayMenuItem(rawValue: id),
            item != .separator
        else { return nil }
        return item
    }

    /// GetGroupProperties: an empty list means every item.
    public static func findRequested(_ ids: [Int32]) -> [TrayMenuItem]
    {
        guard !ids.isEmpty else { return allCases }
        return ids.compactMap { TrayMenuItem(rawValue: $0) }
    }
}

/// The com.canonical.dbusmenu names. StatusNotifierItem hosts read
/// the item's "Menu" path and show this menu on a right click.
public enum DBusMenuProtocol {
    public static let MENU_PATH = "/MenuBar"
    public static let INTERFACE = "com.canonical.dbusmenu"
    public static let ROOT_ID: Int32 = 0
    /// The menu never changes, so its layout keeps one revision.
    public static let LAYOUT_REVISION: UInt32 = 1
    static let PROTOCOL_VERSION: UInt32 = 3
    public static let ROOT_PROPERTIES: [String: TrayPropertyValue] =
        ["children-display": .text("submenu")]

    public static func value(
        named property_Name: String
    ) -> TrayPropertyValue? {
        switch property_Name {
        case "Version": .number(PROTOCOL_VERSION)
        case "TextDirection": .text("ltr")
        case "Status": .text("normal")
        case "IconThemePath": .texts([])
        default: nil
        }
    }

    public static let INTROSPECTION_XML = """
        <node><interface name="com.canonical.dbusmenu">
        <property name="Version" type="u" access="read"/>
        <property name="TextDirection" type="s" access="read"/>
        <property name="Status" type="s" access="read"/>
        <property name="IconThemePath" type="as" access="read"/>
        <method name="GetLayout">
        <arg type="i" name="parentId" direction="in"/>
        <arg type="i" name="recursionDepth" direction="in"/>
        <arg type="as" name="propertyNames" direction="in"/>
        <arg type="u" name="revision" direction="out"/>
        <arg type="(ia{sv}av)" name="layout" direction="out"/>
        </method>
        <method name="GetGroupProperties">
        <arg type="ai" name="ids" direction="in"/>
        <arg type="as" name="propertyNames" direction="in"/>
        <arg type="a(ia{sv})" name="properties" direction="out"/>
        </method>
        <method name="GetProperty">
        <arg type="i" name="id" direction="in"/>
        <arg type="s" name="name" direction="in"/>
        <arg type="v" name="value" direction="out"/></method>
        <method name="Event">
        <arg type="i" name="id" direction="in"/>
        <arg type="s" name="eventId" direction="in"/>
        <arg type="v" name="data" direction="in"/>
        <arg type="u" name="timestamp" direction="in"/></method>
        <method name="EventGroup">
        <arg type="a(isvu)" name="events" direction="in"/>
        <arg type="ai" name="idErrors" direction="out"/></method>
        <method name="AboutToShow">
        <arg type="i" name="id" direction="in"/>
        <arg type="b" name="needUpdate" direction="out"/></method>
        <method name="AboutToShowGroup">
        <arg type="ai" name="ids" direction="in"/>
        <arg type="ai" name="updatesNeeded" direction="out"/>
        <arg type="ai" name="idErrors" direction="out"/></method>
        <signal name="ItemsPropertiesUpdated">
        <arg type="a(ia{sv})" name="updatedProps"/>
        <arg type="a(ias)" name="removedProps"/></signal>
        <signal name="LayoutUpdated">
        <arg type="u" name="revision"/>
        <arg type="i" name="parent"/></signal>
        </interface></node>
        """
}
