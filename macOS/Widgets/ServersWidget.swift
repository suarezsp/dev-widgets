import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Medium and large widget with the user's servers: CPU, memory,
/// disk, load and uptime, read over SSH by the menu bar app.
struct ServersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppGroup.SERVERS_KIND,
            provider: ServersTimelineProvider()
        ) { entry in
            ServersWidgetView(overview: entry.overview)
        }
        .configurationDisplayName("Servers")
        .description("CPU, memory and disk of your Linux servers.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ServersEntry: TimelineEntry {
    let date: Date
    /// nil until the menu bar app has polled once.
    let overview: ServerOverview?
}

struct ServersTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ServersEntry {
        ServersEntry(date: Date(), overview: PreviewData.SERVERS)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (ServersEntry) -> Void
    ) {
        let fallback_Overview =
            context.isPreview ? PreviewData.SERVERS : nil
        completion(
            ServersEntry(
                date: Date(),
                overview: Self.loadOverview() ?? fallback_Overview
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ServersEntry>) -> Void
    ) {
        let entry = ServersEntry(
            date: Date(),
            overview: Self.loadOverview()
        )
        completion(
            Timeline(
                entries: [entry],
                policy: .after(SnapshotLoader.nextFallbackDate())
            )
        )
    }

    static func loadOverview() -> ServerOverview? {
        try? AppGroup.makeServerStore()?.load()
    }
}

/// Medium: up to three servers, as many as fit (a failed host
/// takes one line, a healthy one two); large: six. With the time
/// of the poll.
struct ServersWidgetView: View {
    static let MEDIUM_SERVER_COUNT = 3
    static let LARGE_SERVER_COUNT = 6

    @LayoutFamily private var widget_Family

    let overview: ServerOverview?

    var body: some View {
        Group {
            if let overview {
                VStack(alignment: .leading, spacing: 10) {
                    header(overview)
                    fittingList(overview)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            } else {
                WaitingForDataView()
            }
        }
        .systemWidgetBackground()
    }

    private var row_Limit: Int {
        widget_Family == .systemLarge
            ? Self.LARGE_SERVER_COUNT : Self.MEDIUM_SERVER_COUNT
    }

    /// Drops servers from the end until the list fits.
    private func fittingList(_ overview: ServerOverview) -> some View
    {
        ViewThatFits(in: .vertical) {
            ForEach((1...row_Limit).reversed(), id: \.self) {
                ServerList(overview: overview, row_Limit: $0)
            }
        }
    }

    private func header(_ overview: ServerOverview) -> some View {
        HStack {
            Label("SERVERS", systemImage: "server.rack")
                .labelStyle(CompactLabelStyle())
            Spacer()
            Text(overview.captured_At, style: .time)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}
