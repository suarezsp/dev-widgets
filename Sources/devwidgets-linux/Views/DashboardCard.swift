import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import DevWidgetsPresentation

/// The large dashboard: CPU, memory and network history, and the
/// busiest processes with a quit button each.
final class DashboardCard {
    let widget = Widgets.makeBox(vertical: true, spacing: 8)
    private let time_Label = Widgets.makeLabel(classes: ["secondary"])
    private let cpu_Label = Widgets.makeLabel(classes: ["row-title"])
    private let memory_Label = Widgets.makeLabel(classes: ["caption"])
    private let network_Label = Widgets.makeLabel(classes: ["caption"]
    )
    private let process_Rows: [ProcessRow]
    private var history = MetricHistory()
    private var cpu_Level = LoadLevel.normal
    private lazy var cpu_Chart = Canvas(width: 330, height: 92) {
        [unowned self] cairo, width, height in
        Painters.drawChart(
            cairo,
            size: (width, height),
            series: ChartSeries(
                values: history.cpu_Fractions,
                color: LevelColors.color(cpu_Level),
                maximum: 1
            )
        )
    }
    private lazy var memory_Chart = makeSmallChart {
        [unowned self] in (history.memory_Fractions, 1)
    }
    private lazy var network_Chart = makeSmallChart {
        [unowned self] in (history.download_Rates, nil)
    }

    init(handlers: CardHandlers) {
        process_Rows = (0..<ProcessRow.ROW_COUNT).map { _ in
            ProcessRow(handlers: handlers)
        }
        Widgets.addClasses(widget, ["widget-card"])
        Widgets.fix(widget, size: .large)
        Widgets.append(
            makeHeader(),
            cpu_Label,
            cpu_Chart.widget,
            makeChartPair(),
            ContextRows.makeCaption("Processes"),
            to: widget
        )
        process_Rows.forEach { Widgets.append($0.widget, to: widget) }
    }

    private func makeHeader() -> WidgetPointer {
        let header = Widgets.makeBox(vertical: false, spacing: 6)
        let title_Label = Widgets.makeLabel(
            "This computer",
            classes: ["card-title"]
        )
        Widgets.expand(title_Label, horizontally: true)
        Widgets.append(
            Widgets.makeIcon("computer-symbolic"),
            title_Label,
            time_Label,
            to: header
        )
        return header
    }

    private func makeSmallChart(
        _ values: @escaping () -> ([Double], Double?)
    ) -> Canvas {
        Canvas(width: 158, height: 46) { cairo, width, height in
            let (series_Values, maximum) = values()
            Painters.drawChart(
                cairo,
                size: (width, height),
                series: ChartSeries(
                    values: series_Values,
                    color: LevelColors.ACCENT,
                    maximum: maximum
                )
            )
        }
    }

    private func makeChartPair() -> WidgetPointer {
        let pair = Widgets.makeBox(vertical: false, spacing: 12)
        gtk_box_set_homogeneous(castPointer(pair), 1)
        for (label, chart) in [
            (memory_Label, memory_Chart),
            (network_Label, network_Chart),
        ] {
            let column = Widgets.makeBox(vertical: true, spacing: 2)
            Widgets.append(label, chart.widget, to: column)
            Widgets.append(column, to: pair)
        }
        return pair
    }

    func update(_ snapshot: MetricSnapshot) {
        history = snapshot.history
        let readings = snapshot.readings
        let cpu = MetricKind.cpu.present(readings)
        cpu_Level = cpu.level
        Widgets.setText(cpu_Label, "CPU  \(cpu.value_Text)")
        Widgets.setLevel(cpu_Label, cpu.level)
        let memory = MetricKind.memory.present(readings)
        Widgets.setText(memory_Label, "Memory  \(memory.value_Text)")
        let network = MetricKind.network.present(readings)
        Widgets.setText(network_Label, network.value_Text)
        Widgets.setText(
            time_Label,
            ContextRows.describeTime(snapshot.captured_At)
        )
        [cpu_Chart, memory_Chart, network_Chart].forEach {
            $0.redraw()
        }
        showProcesses(readings.top_Processes)
    }

    private func showProcesses(_ processes: [ProcessUsage]) {
        for (index, row) in process_Rows.enumerated() {
            row.show(index < processes.count ? processes[index] : nil)
        }
    }
}
