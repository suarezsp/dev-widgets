import SwiftUI
import WidgetKit

/// One metric laid out like the system battery widget: a thin ring
/// with the symbol at the top, a large value at the bottom.
struct SmallMetricView: View {
    static let BADGE_SIZE: CGFloat = 60

    let presentation: MetricPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                badge
                Spacer(minLength: 4)
                MetricHeader(presentation: presentation)
            }
            Spacer(minLength: 4)
            MetricValueText(presentation: presentation)
            Text(presentation.detail_Text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        // Without it the column is as wide as the value and ends
        // up centered.
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.spoken_Text)
    }

    private var badge: some View {
        RingGauge(
            fraction: presentation.fraction ?? 0,
            tint: presentation.level.tint
        )
        .overlay {
            Image(systemName: presentation.symbol_Name)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: Self.BADGE_SIZE, height: Self.BADGE_SIZE)
    }
}

/// The large figure of a metric, sized like the system widgets'.
struct MetricValueText: View {
    static let FONT_SIZE: CGFloat = 38

    let presentation: MetricPresentation

    var body: some View {
        Text(presentation.value_Text)
            .font(
                .system(size: Self.FONT_SIZE, weight: .regular)
                    .monospacedDigit()
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
