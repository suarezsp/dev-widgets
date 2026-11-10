/// The macOS widget families, in points, so the Linux dashboard
/// shows the same shapes side by side.
public enum WidgetSize: String, CaseIterable, Sendable {
    case small
    case medium
    case large
    case extra_Large

    public var width: Int {
        switch self {
        case .small: 170
        case .medium, .large: 364
        case .extra_Large: 760
        }
    }

    public var height: Int {
        switch self {
        case .small, .medium: 170
        case .large, .extra_Large: 382
        }
    }
}
