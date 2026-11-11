import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// What the tray icon says: its tooltip, and whether it asks for
/// attention (some panels then show it differently).
public struct TrayState: Equatable, Sendable {
    public static let TITLE = "DevWidgets"
    static let SUMMARY_KINDS: [MetricKind] = [.cpu, .memory, .disk]

    /// "CPU 12% · Memory 40% · Disk 9%".
    public let tooltip_Text: String
    public let needs_Attention: Bool

    public init(tooltip_Text: String, needs_Attention: Bool) {
        self.tooltip_Text = tooltip_Text
        self.needs_Attention = needs_Attention
    }

    public init(readings: MetricReadings) {
        let presentations = Self.SUMMARY_KINDS.map {
            $0.present(readings)
        }
        tooltip_Text = presentations.map {
            "\($0.title) \($0.value_Text)"
        }.joined(separator: " · ")
        needs_Attention = presentations.contains {
            $0.level == .critical
        }
    }

    /// Before the first sample.
    public static let STARTING = TrayState(
        tooltip_Text: "Measuring…",
        needs_Attention: false
    )

    /// StatusNotifierItem's "Status" property.
    public var status_Text: String {
        needs_Attention ? "NeedsAttention" : "Active"
    }
}

/// The D-Bus names of the StatusNotifierItem protocol (KDE,
/// XFCE, LXQt, Budgie, and GNOME with the AppIndicator extension).
public enum StatusNotifierProtocol {
    public static let ITEM_PATH = "/StatusNotifierItem"
    public static let ITEM_INTERFACE = "org.kde.StatusNotifierItem"
    public static let WATCHER_NAME = "org.kde.StatusNotifierWatcher"
    public static let WATCHER_PATH = "/StatusNotifierWatcher"
    public static let REGISTER_METHOD = "RegisterStatusNotifierItem"

    /// The bus name the spec asks each item to own.
    public static func makeBusName(process_ID: Int32) -> String {
        "org.kde.StatusNotifierItem-\(process_ID)-1"
    }

    /// The part of the interface DevWidgets implements: a click
    /// opens the dashboard; "Menu" points at the dbusmenu object.
    public static let INTROSPECTION_XML = """
        <node><interface name="org.kde.StatusNotifierItem">
        <property name="Category" type="s" access="read"/>
        <property name="Id" type="s" access="read"/>
        <property name="Title" type="s" access="read"/>
        <property name="Status" type="s" access="read"/>
        <property name="IconName" type="s" access="read"/>
        <property name="IconThemePath" type="s" access="read"/>
        <property name="ItemIsMenu" type="b" access="read"/>
        <property name="ToolTip" type="(sa(iiay)ss)" access="read"/>
        <property name="Menu" type="o" access="read"/>
        <method name="Activate">
        <arg name="x" type="i" direction="in"/>
        <arg name="y" type="i" direction="in"/></method>
        <method name="SecondaryActivate">
        <arg name="x" type="i" direction="in"/>
        <arg name="y" type="i" direction="in"/></method>
        <method name="ContextMenu">
        <arg name="x" type="i" direction="in"/>
        <arg name="y" type="i" direction="in"/></method>
        <method name="Scroll">
        <arg name="delta" type="i" direction="in"/>
        <arg name="orientation" type="s" direction="in"/></method>
        <signal name="NewToolTip"/><signal name="NewStatus">
        <arg name="status" type="s"/></signal>
        </interface></node>
        """
}

/// One StatusNotifierItem property, before it becomes a GVariant.
public enum TrayPropertyValue: Equatable, Sendable {
    case text(String)
    case flag(Bool)
    /// The (sa(iiay)ss) tooltip: no icon, a title and a body.
    case tooltip(title: String, body: String)
    case number(UInt32)
    case texts([String])
    case object_Path(String)
}

/// The item's properties. `icon_Theme_Path` lets panels find the
/// app icon when DevWidgets runs from a build folder.
public struct TrayProperties: Sendable {
    public static let ICON_NAME = "com.morsetechnologies.DevWidgets"

    public var icon_Theme_Path = ""

    public init(icon_Theme_Path: String = "") {
        self.icon_Theme_Path = icon_Theme_Path
    }

    public func value(
        named property_Name: String,
        state: TrayState
    ) -> TrayPropertyValue? {
        switch property_Name {
        case "Category": .text("SystemServices")
        case "Id": .text("devwidgets")
        case "Title": .text(TrayState.TITLE)
        case "Status": .text(state.status_Text)
        case "IconName": .text(Self.ICON_NAME)
        case "IconThemePath": .text(icon_Theme_Path)
        case "ItemIsMenu": .flag(false)
        case "ToolTip":
            .tooltip(title: TrayState.TITLE, body: state.tooltip_Text)
        case "Menu": .object_Path(DBusMenuProtocol.MENU_PATH)
        default: nil
        }
    }
}
