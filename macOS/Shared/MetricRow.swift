import SwiftUI
import WidgetKit

/// Compact metric line used by the medium widget and the menu bar:
/// small uppercase title, value, then a bar or the detail.
struct MetricRow: View {
    let presentation: MetricPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title_Line
            if let fraction = presentation.fraction {
                LoadBar(
                    fraction: fraction,
                    tint: presentation.level.tint
                )
            } else {
                Text(presentation.detail_Text)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.spoken_Text)
    }

    private var title_Line: some View {
        HStack(alignment: .firstTextBaseline) {
            MetricHeader(presentation: presentation)
            Spacer(minLength: 4)
            Text(presentation.value_Text)
                .font(.callout.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Thin capsule progress bar tinted by load level.
struct LoadBar: View {
    static let HEIGHT: CGFloat = 4

    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(
                        width: geometry.size.width * clamped_Fraction
                    )
                    .widgetAccentable()
            }
        }
        .frame(height: Self.HEIGHT)
    }

    private var clamped_Fraction: Double { min(1, max(0, fraction)) }
}

/// Icon plus small uppercase title, like the system widgets'
/// labels; colored and marked with a warning sign only when the
/// level needs attention, so color is never the only cue.
struct MetricHeader: View {
    static let WARNING_SYMBOL = "exclamationmark.triangle.fill"

    let presentation: MetricPresentation

    var body: some View {
        HStack(spacing: 3) {
            title_Label
            if presentation.level != .normal {
                Image(systemName: Self.WARNING_SYMBOL)
                    .font(.caption2)
                    .foregroundStyle(presentation.level.tint)
                    .widgetAccentable()
            }
        }
    }

    private var title_Label: some View {
        Label(
            presentation.title.uppercased(),
            systemImage: presentation.symbol_Name
        )
        .font(.caption2.weight(.semibold))
        .labelStyle(CompactLabelStyle())
        .foregroundStyle(presentation.level.label_Style)
        .lineLimit(1)
        .widgetAccentable()
    }
}

/// Icon and title closer together than the default label.
struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
