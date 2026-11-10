import DevWidgetsCore
import SwiftUI

/// Icon button in a panel row. Destructive actions ask first with
/// a confirmation dialog, which the panel (unlike a widget) can
/// show.
struct PanelActionButton: View {
    let action: WidgetAction
    let handler: ActionHandler

    @State private var is_Confirming = false

    var body: some View {
        Button {
            if action.needs_Confirmation {
                is_Confirming = true
            } else {
                perform()
            }
        } label: {
            Image(systemName: action.symbol_Name)
        }
        .buttonStyle(.borderless)
        .help(action.title)
        .confirmationDialog(
            "\(action.title)?",
            isPresented: $is_Confirming
        ) {
            Button(action.title, role: .destructive) { perform() }
        } message: {
            Text(action.consequence_Text)
        }
    }

    private func perform() {
        Task { await handler.perform(action) }
    }
}
