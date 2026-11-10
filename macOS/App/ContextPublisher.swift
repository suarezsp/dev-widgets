import DevWidgetsCore
import Foundation
import WidgetKit

/// Saves every context for the widget and asks WidgetKit to reload
/// the context widget only when its meaning changed.
struct ContextPublisher {
    private let store: ContextStore?
    private var reload_Throttle = ReloadThrottle<ContextShape>(
        min_Reload_Seconds: ContextShape.MIN_RELOAD_SECONDS
    )

    init(store: ContextStore?) {
        self.store = store
    }

    mutating func publish(_ context: DeveloperContext) {
        guard let store, (try? store.save(context)) != nil else {
            return
        }
        guard
            reload_Throttle.shouldReload(
                for: ContextShape(context),
                at: Date()
            )
        else { return }
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppGroup.CONTEXT_KIND
        )
    }
}
