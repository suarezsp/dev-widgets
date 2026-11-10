import DevWidgetsCore
import SwiftUI

/// Gauge icon plus current CPU load in the menu bar.
struct MenuBarLabel: View {
    let snapshot: MetricSnapshot?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.50percent")
            if let cpu = snapshot?.readings.cpu {
                Text(
                    MetricFormatting.describePercent(
                        fraction: cpu.total_Fraction
                    )
                )
                .monospacedDigit()
            }
        }
    }
}
