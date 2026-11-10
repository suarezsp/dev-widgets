import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import DevWidgetsPresentation

/// Adwaita icon names for the metrics.
enum MetricIcons {
    static func name(_ kind: MetricKind) -> String {
        switch kind {
        case .cpu: "computer-symbolic"
        case .memory: "drive-harddisk-solidstate-symbolic"
        case .disk: "drive-harddisk-symbolic"
        case .network: "network-transmit-receive-symbolic"
        case .gpu: "preferences-system-devices-symbolic"
        case .thermal: "dialog-warning-symbolic"
        case .battery: "battery-symbolic"
        }
    }
}

/// Adwaita icon names for the action buttons, as
/// `WidgetAction.symbol_Name` gives SF Symbols on macOS.
enum ActionIcons {
    static func name(_ action: WidgetAction) -> String {
        switch action {
        case .stop_Container: "media-playback-stop-symbolic"
        case .restart_Container: "view-refresh-symbolic"
        case .terminate_Process: "window-close-symbolic"
        case .open_Project: "folder-open-symbolic"
        }
    }
}

/// Header, ring with the value and a detail line: the small
/// widget's content. Rates (network) show two lines instead.
final class MetricRing {
    let widget = Widgets.makeBox(vertical: true, spacing: 6)
    private let kind: MetricKind
    private let header = Widgets.makeBox(vertical: false, spacing: 5)
    private let value_Label = Widgets.makeLabel(classes: [
        "ring-value"
    ])
    private let detail_Label = Widgets.makeLabel(classes: [
        "secondary"
    ])
    private var fill = (fraction: 0.0, level: LoadLevel.normal)
    private lazy var ring = Canvas(width: 96, height: 96) {
        [unowned self] cairo, width, height in
        Painters.drawRing(
            cairo,
            size: (width, height),
            fill: fill
        )
    }

    init(kind: MetricKind) {
        self.kind = kind
        let title_Label = Widgets.makeLabel(
            kind.title,
            classes: ["card-title"]
        )
        Widgets.append(
            Widgets.makeIcon(MetricIcons.name(kind)),
            title_Label,
            to: header
        )
        Widgets.append(
            header,
            makeRingOverlay(),
            detail_Label,
            to: widget
        )
        gtk_widget_set_hexpand(widget, 1)
    }

    private func makeRingOverlay() -> WidgetPointer {
        let overlay = created(gtk_overlay_new())
        gtk_overlay_set_child(castPointer(overlay), ring.widget)
        gtk_widget_set_halign(value_Label, GTK_ALIGN_CENTER)
        gtk_widget_set_valign(value_Label, GTK_ALIGN_CENTER)
        gtk_overlay_add_overlay(castPointer(overlay), value_Label)
        gtk_widget_set_vexpand(overlay, 1)
        return overlay
    }

    func update(_ readings: MetricReadings) {
        let presentation = kind.present(readings)
        Widgets.setText(value_Label, presentation.value_Text)
        Widgets.setText(detail_Label, presentation.detail_Text)
        Widgets.setLevel(header, presentation.level)
        fill = (presentation.fraction ?? 0, presentation.level)
        let is_Rate = presentation.fraction == nil
        gtk_widget_set_visible(ring.widget, is_Rate ? 0 : 1)
        Widgets.addClasses(value_Label, is_Rate ? ["rate-value"] : [])
        ring.redraw()
    }
}

/// Icon, title, value and a thin bar: one row of the medium
/// widget and of the panel.
final class MetricRow {
    let widget = Widgets.makeBox(vertical: false, spacing: 8)
    private let kind: MetricKind
    private let title_Label: WidgetPointer
    private let value_Label = Widgets.makeLabel(classes: ["row-value"]
    )
    private var fill = (fraction: 0.0, level: LoadLevel.normal)
    private lazy var bar = Canvas(width: 60, height: 4) {
        [unowned self] cairo, width, _ in
        Painters.drawBar(cairo, width: width, fill: fill)
    }

    init(kind: MetricKind) {
        self.kind = kind
        title_Label = Widgets.makeLabel(
            kind.title,
            classes: ["row-title"]
        )
        let line = Widgets.makeBox(vertical: false, spacing: 4)
        Widgets.expand(title_Label, horizontally: true)
        Widgets.append(title_Label, value_Label, to: line)
        let body = Widgets.makeBox(vertical: true, spacing: 3)
        Widgets.expand(body, horizontally: true)
        Widgets.append(line, bar.widget, to: body)
        Widgets.append(
            Widgets.makeIcon(MetricIcons.name(kind)),
            body,
            to: widget
        )
    }

    func update(_ readings: MetricReadings) {
        let presentation = kind.present(readings)
        Widgets.setText(value_Label, presentation.value_Text)
        Widgets.setLevel(widget, presentation.level)
        fill = (presentation.fraction ?? 0, presentation.level)
        gtk_widget_set_visible(
            bar.widget,
            presentation.fraction == nil ? 0 : 1
        )
        bar.redraw()
    }
}

/// The small widget: one metric with its ring.
final class SmallMetricCard {
    let widget = Widgets.makeBox(vertical: true)
    private let ring: MetricRing

    init(kind: MetricKind) {
        ring = MetricRing(kind: kind)
        Widgets.addClasses(widget, ["widget-card"])
        Widgets.fix(widget, size: .small)
        Widgets.append(ring.widget, to: widget)
    }

    func update(_ readings: MetricReadings) {
        ring.update(readings)
    }
}

/// The medium widget: the chosen metric's ring and three rows.
final class MediumMetricCard {
    static let ROW_KINDS: [MetricKind] = [
        .cpu, .memory, .disk, .network,
    ]

    let widget = Widgets.makeBox(vertical: false, spacing: 16)
    private let ring: MetricRing
    private let rows: [MetricRow]

    init(kind: MetricKind) {
        ring = MetricRing(kind: kind)
        rows = Self.ROW_KINDS.filter { $0 != kind }.map {
            MetricRow(kind: $0)
        }
        Widgets.addClasses(widget, ["widget-card"])
        Widgets.fix(widget, size: .medium)
        let rows_Box = Widgets.makeBox(vertical: true, spacing: 10)
        gtk_widget_set_valign(rows_Box, GTK_ALIGN_CENTER)
        Widgets.expand(rows_Box, horizontally: true)
        rows.forEach { Widgets.append($0.widget, to: rows_Box) }
        Widgets.append(ring.widget, rows_Box, to: widget)
    }

    func update(_ readings: MetricReadings) {
        ring.update(readings)
        rows.forEach { $0.update(readings) }
    }
}
