import DevWidgetsCore
import SwiftUI

/// Constants shared by every process and container row.
enum ProcessColumns {
    static let MEMORY_WIDTH: CGFloat = 52
    static let CPU_WIDTH: CGFloat = 40
}

/// Busiest processes: name, CPU (100 % = one core) and memory. The
/// accessory is the quit button, as in `ContainerList`.
struct ProcessList<Accessory: View>: View {
    let processes: [ProcessUsage]
    let row_Limit: Int
    @ViewBuilder let accessory: (ProcessUsage) -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TOP PROCESSES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if processes.isEmpty {
                Text("Waiting for a second sample")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(processes.prefix(row_Limit), id: \.identity) {
                processRow($0)
            }
        }
    }
}

extension ProcessList {
    fileprivate func processRow(_ process: ProcessUsage) -> some View
    {
        HStack(spacing: 4) {
            ProcessRow(process: process)
            accessory(process)
        }
    }
}

extension ProcessList where Accessory == EmptyView {
    init(processes: [ProcessUsage], row_Limit: Int) {
        self.init(processes: processes, row_Limit: row_Limit) { _ in
            EmptyView()
        }
    }
}

struct ProcessRow: View {
    let process: ProcessUsage

    var body: some View {
        HStack(spacing: 6) {
            Text(process.identity.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(
                MetricFormatting.describeCoreShare(
                    process.cpu_Fraction
                )
            )
            .frame(
                width: ProcessColumns.CPU_WIDTH,
                alignment: .trailing
            )
            Text(memory_Text)
                .foregroundStyle(.secondary)
                .frame(
                    width: ProcessColumns.MEMORY_WIDTH,
                    alignment: .trailing
                )
        }
        .font(.caption2.monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    private var memory_Text: String {
        MetricFormatting.describe(
            bytes: Double(process.resident_Bytes)
        )
    }
}
