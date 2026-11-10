import DevWidgetsCore
import SwiftUI

extension LoadLevel {
    /// Monochrome while healthy, like the system widgets; amber and
    /// red only when a value needs attention.
    var tint: Color {
        switch self {
        case .normal: .primary
        case .elevated: .orange
        case .critical: .red
        }
    }

    /// Icon and title color: secondary while healthy.
    var label_Style: AnyShapeStyle {
        self == .normal
            ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint)
    }
}
