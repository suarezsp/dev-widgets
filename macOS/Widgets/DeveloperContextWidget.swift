import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Medium and large widget with the project's Git status, Docker
/// containers and listening ports.
struct DeveloperContextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: AppGroup.CONTEXT_KIND,
            provider: ContextTimelineProvider()
        ) { entry in
            DeveloperContextWidgetView(
                context: entry.context,
                armed_Action: entry.armed_Action
            )
        }
        .configurationDisplayName("Developer Context")
        .description(
            "Git, GitHub CI and pull request, containers and ports."
        )
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ContextEntry: TimelineEntry {
    let date: Date
    /// nil until the menu bar app has read the context once.
    let context: DeveloperContext?
    var armed_Action: WidgetAction?
}

struct ContextTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContextEntry {
        ContextEntry(date: Date(), context: PreviewData.CONTEXT)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (ContextEntry) -> Void
    ) {
        let stored_Context = try? AppGroup.makeContextStore()?.load()
        let fallback_Context =
            context.isPreview ? PreviewData.CONTEXT : nil
        completion(
            ContextEntry(
                date: Date(),
                context: stored_Context ?? fallback_Context
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ContextEntry>) -> Void
    ) {
        let stored_Context = try? AppGroup.makeContextStore()?.load()
        let entries = ArmedActionTimeline.makeDates().map {
            ContextEntry(
                date: $0.date,
                context: stored_Context,
                armed_Action: $0.armed
            )
        }
        completion(
            Timeline(
                entries: entries,
                policy: .after(SnapshotLoader.nextFallbackDate())
            )
        )
    }
}

struct DeveloperContextWidgetView: View {
    let context: DeveloperContext?
    let armed_Action: WidgetAction?

    var body: some View {
        Group {
            if let context {
                DeveloperContextView(
                    context: context,
                    armed_Action: armed_Action
                )
            } else {
                WaitingForDataView()
            }
        }
        .systemWidgetBackground()
    }
}
