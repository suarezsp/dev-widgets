import SwiftUI
import WidgetKit

extension View {
    /// The system's own widget background, as in Xcode's widget
    /// template. In the clear and tinted presentations macOS 26
    /// removes it and draws its Liquid Glass, so the widgets add no
    /// fill, gradient or material of their own.
    func systemWidgetBackground() -> some View {
        containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Thin ring with the metric's symbol inside, like the system
/// battery widget.
struct RingGauge: View {
    static let LINE_WIDTH: CGFloat = 5

    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: Self.LINE_WIDTH)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(
                    tint,
                    style: StrokeStyle(
                        lineWidth: Self.LINE_WIDTH,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .padding(Self.LINE_WIDTH / 2)
    }
}

/// Shown until the menu bar app publishes its first snapshot. It
/// does not claim the app is closed: the app may be open but
/// unable to share data, which its panel then explains.
struct WaitingForDataView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "menubar.rectangle")
                .font(.title2)
                .widgetAccentable()
            Text("No data yet. Open DevWidgets in the menu bar.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
