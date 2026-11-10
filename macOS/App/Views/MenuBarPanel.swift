import AppKit
import DevWidgetsCore
import SwiftUI

/// Window-style menu bar panel in two columns: Liquid Glass cards
/// for the metrics this Mac has and the servers on the left;
/// busiest processes and the developer context on the right.
struct MenuBarPanel: View {
    static let COLUMN_WIDTH: CGFloat = 290
    static let CARD_CORNER_RADIUS: CGFloat = 14

    let model: LiveMetricsModel
    let context_Model: DeveloperContextModel
    let servers_Model: ServersModel
    let handler: ActionHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(
                local_Address: model.latest_Snapshot?.readings
                    .local_Address
            )
            HStack(alignment: .top, spacing: 14) {
                machine_Column.frame(width: Self.COLUMN_WIDTH)
                context_Column.frame(width: Self.COLUMN_WIDTH)
            }
            ForEach(problem_Texts, id: \.self) { problem_Text in
                Label(
                    problem_Text,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.red)
            }
            Divider()
            Button("Quit DevWidgets") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
    }

    private var problem_Texts: [String] {
        [model.last_Error_Text, model.widget_Problem_Text]
            .compactMap { $0 }
    }

    private var machine_Column: some View {
        VStack(alignment: .leading, spacing: 12) {
            readings_Section
            ServerSection(model: servers_Model)
        }
    }

    private var context_Column: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProcessList(
                processes: model.latest_Snapshot?.readings
                    .top_Processes ?? [],
                row_Limit: ProcessRanking.TOP_COUNT
            ) {
                PanelActionButton(
                    action: .terminate_Process(process: $0.identity),
                    handler: handler
                )
            }
            DeveloperSection(model: context_Model, handler: handler)
        }
    }

    @ViewBuilder
    private var readings_Section: some View {
        if let readings = model.latest_Snapshot?.readings {
            metricCards(readings)
        } else {
            ProgressView("Collecting first sample…")
        }
    }

    private func metricCards(
        _ readings: MetricReadings
    ) -> some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(availablePresentations(readings), id: \.kind)
                {
                    MetricRow(presentation: $0)
                        .padding(10)
                        .glassEffect(
                            .regular,
                            in: .rect(
                                cornerRadius: Self.CARD_CORNER_RADIUS
                            )
                        )
                }
            }
        }
    }

    private func availablePresentations(
        _ readings: MetricReadings
    ) -> [MetricPresentation] {
        MetricKind.allCases
            .map { $0.present(readings) }
            .filter(\.is_Available)
    }
}

struct PanelHeader: View {
    let local_Address: String?

    @Environment(\.openSettings) private var open_Settings

    var body: some View {
        HStack {
            Text("DevWidgets").font(.headline)
            Spacer()
            if let local_Address {
                Text(local_Address)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Button {
                // A menu bar app must come forward, or Settings
                // opens behind the frontmost app.
                NSApplication.shared.activate()
                open_Settings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings: alerts, GitHub, servers, editor")
        }
    }
}

/// The monitored servers under the metric cards.
struct ServerSection: View {
    static let SERVER_COUNT = 4

    let model: ServersModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Servers", systemImage: "server.rack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ServerList(
                overview: model.overview,
                row_Limit: Self.SERVER_COUNT
            )
        }
    }
}
