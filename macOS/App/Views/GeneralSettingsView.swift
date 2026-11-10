import SwiftUI

/// Start at login. It reads the real state from ServiceManagement
/// each time the tab opens, so a change in System Settings shows.
struct GeneralSettingsView: View {
    @State private var is_On = LoginItem.is_Enabled
    @State private var error_Text: String?

    var body: some View {
        Form {
            Toggle("Start DevWidgets at login", isOn: $is_On)
                .onChange(of: is_On) { _, new_Value in
                    applyChoice(new_Value)
                }
            Text(note_Text)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error_Text {
                Text(error_Text)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onAppear { is_On = LoginItem.is_Enabled }
    }

    private var note_Text: String {
        if LoginItem.needs_Approval {
            return "Allow DevWidgets in System Settings › General ›"
                + " Login Items."
        }
        return "The widgets only get new data while DevWidgets runs."
    }

    /// Skips values that already match, such as the reset after a
    /// failure, so ServiceManagement is only called for real changes.
    private func applyChoice(_ new_Value: Bool) {
        guard new_Value != LoginItem.is_Enabled else { return }
        do {
            try LoginItem.setEnabled(new_Value)
            error_Text = nil
        } catch {
            error_Text = error.localizedDescription
            is_On = LoginItem.is_Enabled
        }
    }
}
