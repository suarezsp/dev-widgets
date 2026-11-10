import CGtk
import DevWidgetsCore
import Foundation

/// The level colours of the macOS widgets (system green, orange,
/// red), in their light and dark variants.
enum LevelColors {
    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    static let LIGHT: [LoadLevel: RGB] = [
        .normal: RGB(red: 0.204, green: 0.780, blue: 0.349),
        .elevated: RGB(red: 1.0, green: 0.584, blue: 0.0),
        .critical: RGB(red: 1.0, green: 0.231, blue: 0.188),
    ]
    static let DARK: [LoadLevel: RGB] = [
        .normal: RGB(red: 0.188, green: 0.820, blue: 0.345),
        .elevated: RGB(red: 1.0, green: 0.624, blue: 0.039),
        .critical: RGB(red: 1.0, green: 0.271, blue: 0.227),
    ]
    static let ACCENT = RGB(red: 0.039, green: 0.518, blue: 1.0)

    static var is_Dark: Bool {
        adw_style_manager_get_dark(adw_style_manager_get_default())
            != 0
    }

    static func color(_ level: LoadLevel) -> RGB {
        (is_Dark ? DARK : LIGHT)[level] ?? ACCENT
    }

    static func className(_ level: LoadLevel) -> String {
        switch level {
        case .normal: "normal"
        case .elevated: "elevated"
        case .critical: "critical"
        }
    }
}

/// A GtkDrawingArea whose content a Swift closure paints with
/// Cairo; `redraw` after the values change.
final class Canvas {
    typealias Painter = (OpaquePointer, Double, Double) -> Void

    private static let DRAW:
        @convention(c) (
            UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?,
            Int32, Int32, UnsafeMutableRawPointer?
        ) -> Void = { _, cairo, width, height, data in
            guard let cairo, let data else { return }
            Unmanaged<Canvas>.fromOpaque(data).takeUnretainedValue()
                .painter(cairo, Double(width), Double(height))
        }

    let widget: WidgetPointer
    var painter: Painter

    init(width: Int32, height: Int32, painter: @escaping Painter) {
        widget = gtk_drawing_area_new()
        self.painter = painter
        gtk_widget_set_size_request(widget, width, height)
        gtk_drawing_area_set_draw_func(
            castPointer(widget),
            Self.DRAW,
            Unmanaged.passRetained(self).toOpaque(),
            RELEASE_BOX
        )
    }

    func redraw() {
        gtk_widget_queue_draw(widget)
    }
}

/// Rings, bars and history charts, as the SwiftUI views draw them.
enum Painters {
    static func setColor(
        _ cairo: OpaquePointer,
        _ rgb: LevelColors.RGB,
        alpha: Double = 1
    ) {
        cairo_set_source_rgba(
            cairo,
            rgb.red,
            rgb.green,
            rgb.blue,
            alpha
        )
    }

    /// The unfilled part: system grey at a third.
    static func setTrack(_ cairo: OpaquePointer) {
        cairo_set_source_rgba(cairo, 0.47, 0.47, 0.5, 0.3)
    }

    /// A 9-point ring starting at 12 o'clock.
    static func drawRing(
        _ cairo: OpaquePointer,
        size: (width: Double, height: Double),
        fill: (fraction: Double, level: LoadLevel)
    ) {
        let radius = min(size.width, size.height) / 2 - 6
        cairo_set_line_width(cairo, 9)
        cairo_set_line_cap(cairo, CAIRO_LINE_CAP_ROUND)
        cairo_translate(cairo, size.width / 2, size.height / 2)
        setTrack(cairo)
        cairo_arc(cairo, 0, 0, radius, 0, 2 * .pi)
        cairo_stroke(cairo)
        let sweep = 2 * Double.pi * min(1, max(0, fill.fraction))
        guard sweep > 0 else { return }
        setColor(cairo, LevelColors.color(fill.level))
        // Turned a quarter back, so the arc starts at the top.
        cairo_rotate(cairo, -Double.pi / 2)
        cairo_arc(cairo, 0, 0, radius, 0, sweep)
        cairo_stroke(cairo)
    }

    /// A 4-point rounded bar, filled to `fraction`.
    static func drawBar(
        _ cairo: OpaquePointer,
        width: Double,
        fill: (fraction: Double, level: LoadLevel)
    ) {
        cairo_set_line_width(cairo, 4)
        cairo_set_line_cap(cairo, CAIRO_LINE_CAP_ROUND)
        setTrack(cairo)
        cairo_move_to(cairo, 2, 2)
        cairo_line_to(cairo, width - 2, 2)
        cairo_stroke(cairo)
        let filled_Width = (width - 4) * min(1, max(0, fill.fraction))
        guard filled_Width > 0 else { return }
        setColor(cairo, LevelColors.color(fill.level))
        cairo_move_to(cairo, 2, 2)
        cairo_line_to(cairo, 2 + filled_Width, 2)
        cairo_stroke(cairo)
    }

    /// Area chart, oldest value on the left. Percentages use a
    /// fixed 0...1 scale; rates (`maximum` nil) follow their peak.
    static func drawChart(
        _ cairo: OpaquePointer,
        size: (width: Double, height: Double),
        series: ChartSeries
    ) {
        guard series.values.count > 1 else { return }
        traceArea(cairo, size: size, series: series)
        cairo_close_path(cairo)
        setColor(cairo, series.color, alpha: 0.22)
        cairo_fill_preserve(cairo)
        setColor(cairo, series.color)
        cairo_set_line_width(cairo, 1.6)
        cairo_stroke(cairo)
    }
}

extension Painters {
    /// The outline under the values, closed along the bottom.
    static func traceArea(
        _ cairo: OpaquePointer,
        size: (width: Double, height: Double),
        series: ChartSeries
    ) {
        let values = series.values
        let peak = series.maximum ?? max(values.max() ?? 0, 1e-9)
        let step_Width = size.width / Double(values.count - 1)
        cairo_move_to(cairo, 0, size.height)
        for (index, value) in values.enumerated() {
            let ratio = min(1, value / peak)
            cairo_line_to(
                cairo,
                Double(index) * step_Width,
                size.height - ratio * (size.height - 2)
            )
        }
        cairo_line_to(cairo, size.width, size.height)
    }
}

/// One line of a history chart.
struct ChartSeries {
    let values: [Double]
    let color: LevelColors.RGB
    /// nil: the scale follows the peak.
    let maximum: Double?
}
