import AppIntents
import DevWidgetsCore
import SwiftUI

/// Small icon button in a widget row. When its action is armed,
/// it turns into a red "Confirm" that performs it.
struct WidgetActionButton<Intent: AppIntent>: View {
    let action: WidgetAction
    let armed_Action: WidgetAction?
    let intent: Intent

    var body: some View {
        Button(intent: intent) {
            if armed_Action == action {
                Text("Confirm")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                Image(systemName: action.symbol_Name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

extension WidgetActionButton where Intent == ContainerActionIntent {
    /// The stop button, or with `restarts` the restart button.
    init(
        container: ContainerIdentity,
        restarts: Bool,
        armed_Action: WidgetAction?
    ) {
        self.init(
            action: restarts
                ? .restart_Container(container: container)
                : .stop_Container(container: container),
            armed_Action: armed_Action,
            intent: ContainerActionIntent(
                container: container,
                restarts: restarts
            )
        )
    }
}

extension WidgetActionButton where Intent == TerminateProcessIntent {
    init(process: ProcessIdentity, armed_Action: WidgetAction?) {
        self.init(
            action: .terminate_Process(process: process),
            armed_Action: armed_Action,
            intent: TerminateProcessIntent(process: process)
        )
    }
}
