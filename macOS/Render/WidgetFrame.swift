import SwiftUI
import WidgetKit

/// How the desktop presents the widget. `clear` is the Liquid
/// Glass look of macOS 26 (accented rendering): the host removes
/// the background and tints the content white. `ImageRenderer`
/// does neither, so the frame does it: content masked onto white,
/// no background. The glass itself is drawn afterwards by
/// tools/compose_widget_renders.py, an emulation.
enum RenderMode: String, CaseIterable {
    case clear
    case dark
    case light

    var color_Scheme: ColorScheme { self == .light ? .light : .dark }

    var rendering_Mode: WidgetRenderingMode {
        self == .clear ? .accented : .fullColor
    }
}

/// macOS widget sizes in points and how the images are framed.
enum WidgetCanvas {
    static let SCALE: CGFloat = 2
    static let CORNER_RADIUS: CGFloat = 22
    /// The system's default content margins on the desktop.
    static let CONTENT_PADDING: CGFloat = 16

    static func size(of family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        case .systemExtraLarge: CGSize(width: 760, height: 382)
        default: CGSize(width: 364, height: 382)
        }
    }
}

/// One widget on a transparent canvas, in one presentation.
struct WidgetFrame: View {
    let job: RenderJob
    let mode: RenderMode

    var body: some View {
        let size = WidgetCanvas.size(of: job.family)
        presented_Content
            .frame(width: size.width, height: size.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: WidgetCanvas.CORNER_RADIUS,
                    style: .continuous
                )
            )
            .environment(\.requested_Family, job.family)
            .environment(\.colorScheme, mode.color_Scheme)
            .environment(\.widgetRenderingMode, mode.rendering_Mode)
    }

    /// Full color keeps the widget's own `.fill.tertiary`, which
    /// WidgetKit would draw from `containerBackground`.
    @ViewBuilder private var presented_Content: some View {
        let padded = job.content.padding(WidgetCanvas.CONTENT_PADDING)
        if mode == .clear {
            Color.white.mask { padded }
        } else {
            padded.background(.fill.tertiary)
        }
    }
}
