import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Icon, headline and detail for one part of the context.
struct ContextRow: View {
    let symbol_Name: String
    let line: ContextLine

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol_Name)
                .foregroundStyle(line.level.label_Style)
                .frame(width: 18)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(line.detail_Text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Running containers, busiest first, with CPU and memory. The
/// accessory is the stop button: an App Intent in widgets, a
/// confirmation dialog in the panel.
struct ContainerList<Accessory: View>: View {
    let docker: DockerState
    let row_Limit: Int
    @ViewBuilder let accessory: (ContainerUsage) -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ContextRow(
                symbol_Name: "shippingbox",
                line: ContextPresentation.describeDocker(docker)
            )
            ForEach(busiest_Containers, id: \.identity) { container in
                HStack(spacing: 4) {
                    ContainerRow(container: container)
                    accessory(container)
                }
            }
        }
    }

    private var busiest_Containers: [ContainerUsage] {
        docker.listBusiest(limit: row_Limit)
    }
}

extension ContainerList where Accessory == EmptyView {
    init(docker: DockerState, row_Limit: Int) {
        self.init(docker: docker, row_Limit: row_Limit) { _ in
            EmptyView()
        }
    }
}

struct ContainerRow: View {
    let container: ContainerUsage

    /// The medium widget's column is too narrow for name, CPU,
    /// memory and a button: memory goes first.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                name_Text
                Spacer(minLength: 4)
                Text(cpu_Text)
                Text(memory_Text)
                    .foregroundStyle(.secondary)
                    .frame(
                        width: ProcessColumns.MEMORY_WIDTH,
                        alignment: .trailing
                    )
            }
            HStack(spacing: 6) {
                name_Text
                Spacer(minLength: 4)
                Text(cpu_Text)
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(.leading, 26)
        .accessibilityElement(children: .combine)
    }

    private var name_Text: some View {
        Text(container.identity.name)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var cpu_Text: String {
        container.cpu_Fraction.map(MetricFormatting.describeCoreShare)
            ?? "—"
    }

    private var memory_Text: String {
        container.memory_Bytes
            .map { MetricFormatting.describe(bytes: Double($0)) }
            ?? "—"
    }
}

/// Listening TCP ports grouped by program: what is serving here.
struct PortList: View {
    let ports: [ListeningPort]
    /// Maximum number of programs shown.
    let row_Limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(
                "LISTENING PORTS",
                systemImage: "point.3.connected.trianglepath.dotted"
            )
            .labelStyle(CompactLabelStyle())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            if ports.isEmpty {
                Text("None").font(.caption2).foregroundStyle(
                    .secondary
                )
            }
            ForEach(port_Groups, id: \.owner_Name) {
                PortGroupRow(group: $0)
            }
        }
    }

    private var port_Groups: [PortGroup] {
        Array(ContextPresentation.groupPorts(ports).prefix(row_Limit))
    }
}

struct PortGroupRow: View {
    let group: PortGroup

    var body: some View {
        HStack(spacing: 6) {
            Text(group.owner_Name).lineLimit(1)
            Spacer(minLength: 4)
            Text(group.ports_Text)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.monospacedDigit())
    }
}

/// Pull request and CI; a tap opens the failing run or the PR.
struct GitHubRow: View {
    let github: GitHubState

    var body: some View {
        if let page_URL = GitHubPresentation.findPage(github) {
            Link(destination: page_URL) { row }
        } else {
            row
        }
    }

    private var row: some View {
        ContextRow(
            symbol_Name: "checkmark.seal",
            line: GitHubPresentation.describe(github)
        )
    }
}
