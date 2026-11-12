import CGtk
import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// The large servers widget: one row per host with load, memory
/// and disk gauges.
final class ServersCard {
    static let HOST_LIMIT = 4

    let widget = Widgets.makeBox(vertical: true, spacing: 8)
    private let time_Label = Widgets.makeLabel(classes: ["secondary"])
    private let rows_Box = Widgets.makeBox(
        vertical: true,
        spacing: 10
    )

    init() {
        Widgets.addClasses(widget, ["widget-card"])
        Widgets.fix(widget, size: .large)
        let header = Widgets.makeBox(vertical: false, spacing: 6)
        let title_Label = Widgets.makeLabel(
            String(localized: "Servers"),
            classes: ["card-title"]
        )
        Widgets.expand(title_Label, horizontally: true)
        Widgets.append(
            Widgets.makeIcon("network-server-symbolic"),
            title_Label,
            time_Label,
            to: header
        )
        Widgets.append(header, rows_Box, to: widget)
    }

    func update(_ overview: ServerOverview) {
        Widgets.setText(
            time_Label,
            ContextRows.describeTime(overview.captured_At)
        )
        Widgets.removeChildren(rows_Box)
        guard !overview.reports.isEmpty else {
            Widgets.append(
                Widgets.makeLabel(
                    String(
                        localized: "Add an SSH alias in Preferences"
                    ),
                    classes: ["secondary"]
                ),
                to: rows_Box
            )
            return
        }
        for report in overview.reports.prefix(Self.HOST_LIMIT) {
            Widgets.append(
                makeHostRow(ServerPresentation.describe(report)),
                to: rows_Box
            )
        }
    }

    private func makeHostRow(_ line: ServerLine) -> WidgetPointer {
        let host_Box = Widgets.makeBox(vertical: true, spacing: 4)
        let context_Line = ContextLine(
            title: line.alias,
            detail_Text: line.detail_Text,
            level: line.level
        )
        Widgets.append(
            ContextRows.makeRow(
                context_Line,
                icon_Name: "network-server-symbolic"
            ),
            to: host_Box
        )
        guard !line.gauges.isEmpty else { return host_Box }
        let gauges_Box = Widgets.makeBox(vertical: false, spacing: 10)
        gtk_box_set_homogeneous(castPointer(gauges_Box), 1)
        Widgets.addClasses(gauges_Box, ["indented"])
        for gauge in line.gauges {
            Widgets.append(Self.makeGauge(gauge), to: gauges_Box)
        }
        Widgets.append(gauges_Box, to: host_Box)
        return host_Box
    }

    static func makeGauge(_ gauge: ServerGauge) -> WidgetPointer {
        let column = Widgets.makeBox(vertical: true, spacing: 3)
        let line = Widgets.makeBox(vertical: false, spacing: 4)
        let title_Label = Widgets.makeLabel(
            gauge.title,
            classes: ["caption", "secondary"]
        )
        Widgets.expand(title_Label, horizontally: true)
        let value_Label = Widgets.makeLabel(
            gauge.value_Text,
            classes: ["caption"]
        )
        Widgets.setLevel(value_Label, gauge.level)
        Widgets.append(title_Label, value_Label, to: line)
        let fill = (fraction: gauge.fraction ?? 0, level: gauge.level)
        let bar = Canvas(width: 60, height: 4) { cairo, width, _ in
            Painters.drawBar(cairo, width: width, fill: fill)
        }
        Widgets.append(line, bar.widget, to: column)
        return column
    }
}
