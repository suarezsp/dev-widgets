import SwiftUI
import WidgetKit

/// The family a widget lays itself out for. WidgetKit's
/// `widgetFamily` is read-only, so the preview renderer asks for a
/// family through `requested_Family`; inside a widget it is nil.
@propertyWrapper
struct LayoutFamily: DynamicProperty {
    @Environment(\.widgetFamily) private var widget_Family
    @Environment(\.requested_Family) private var requested_Family

    var wrappedValue: WidgetFamily {
        requested_Family ?? widget_Family
    }
}

private struct RequestedFamilyKey: EnvironmentKey {
    static let defaultValue: WidgetFamily? = nil
}

extension EnvironmentValues {
    var requested_Family: WidgetFamily? {
        get { self[RequestedFamilyKey.self] }
        set { self[RequestedFamilyKey.self] = newValue }
    }
}
