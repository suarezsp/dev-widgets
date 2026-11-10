import DevWidgetsCore
import SwiftUI
import WidgetKit

/// One server: name and detail, then CPU, memory and disk bars.
struct ServerRow: View {
    let report: RemoteHostReport

    var body: some View {
        let line = ServerPresentation.describe(report)
        VStack(alignment: .leading, spacing: 4) {
            headline(line)
            if !line.gauges.isEmpty {
                HStack(spacing: 8) {
                    ForEach(line.gauges, id: \.title) {
                        ServerGaugeView(gauge: $0)
                    }
                }
            }
        }
    }

    private func headline(_ line: ServerLine) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(line.level.tint)
                .frame(width: 7, height: 7)
                .widgetAccentable()
            Text(line.alias)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(line.detail_Text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

/// "CPU 12%" over a thin bar.
struct ServerGaugeView: View {
    let gauge: ServerGauge

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(gauge.title).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(gauge.value_Text)
            }
            .font(.caption2.monospacedDigit())
            // Same bar as the other widgets; a ProgressView is an
            // AppKit control that ImageRenderer cannot draw.
            LoadBar(
                fraction: gauge.fraction ?? 0,
                tint: gauge.level.tint
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Every monitored host, or a hint to add some.
struct ServerList: View {
    let overview: ServerOverview
    let row_Limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if overview.reports.isEmpty {
                Text("Add servers in Settings › Servers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(
                overview.reports.prefix(row_Limit),
                id: \.host
            ) {
                ServerRow(report: $0)
            }
        }
    }
}

/// Up to `row_Limit` pull requests awaiting the user, as links.
struct ReviewQueueList: View {
    static let SYMBOL_NAME = "person.crop.circle.badge.questionmark"

    let state: ReviewQueueState
    let row_Limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ContextRow(
                symbol_Name: Self.SYMBOL_NAME,
                line: ReviewQueuePresentation.describe(state)
            )
            ForEach(
                ReviewQueuePresentation.listRequests(
                    state,
                    limit: row_Limit
                ),
                id: \.self
            ) { request in
                ReviewRequestRow(request: request)
            }
        }
    }
}

struct ReviewRequestRow: View {
    let request: ReviewRequest

    var body: some View {
        if let page_URL = request.page_URL {
            Link(destination: page_URL) { row }
        } else {
            row
        }
    }

    private var row: some View {
        let line = ReviewQueuePresentation.describeRequest(request)
        return HStack(spacing: 6) {
            Text(line.title).font(.caption2.weight(.semibold))
            Text(line.detail_Text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.leading, 26)
    }
}
