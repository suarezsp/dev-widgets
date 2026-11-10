import DevWidgetsCore
import SwiftUI

/// The Settings window: start at login, alert thresholds, GitHub
/// access, servers, editor.
struct SettingsView: View {
    static let WIDTH: CGFloat = 520

    let metrics_Model: LiveMetricsModel
    let context_Model: DeveloperContextModel
    let servers_Model: ServersModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            AlertSettingsView(model: metrics_Model)
                .tabItem { Label("Alerts", systemImage: "bell") }
            GitHubSettingsView(context_Model: context_Model)
                .tabItem {
                    Label("GitHub", systemImage: "checkmark.seal")
                }
            ServersSettingsView(model: servers_Model)
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
            EditorSettingsView()
                .tabItem {
                    Label("Project", systemImage: "folder")
                }
        }
        .frame(width: Self.WIDTH)
    }
}

/// One row per metric plus the two anti-spam settings.
struct AlertSettingsView: View {
    @Bindable var model: LiveMetricsModel

    var body: some View {
        Form {
            Section("Notify me when") {
                ForEach($model.alert_Settings.rules, id: \.metric) {
                    AlertRuleRow(rule: $0)
                }
            }
            Section("Avoid noise") {
                Stepper(
                    "Only after \(sustain_Seconds) s past the limit",
                    value: $model.alert_Settings.sustain_Seconds,
                    in: 10...600,
                    step: 10
                )
                Stepper(
                    "At most once every \(cooldown_Minutes) min",
                    value: $model.alert_Settings.cooldown_Seconds,
                    in: 300...7_200,
                    step: 300
                )
            }
            events_Section
        }
        .formStyle(.grouped)
    }

    /// Events have no limit to tune: CI fails, a server stays
    /// unreachable for a minute.
    private var events_Section: some View {
        Section("Events") {
            Toggle(
                "When the project's branch CI fails",
                isOn: $model.alert_Settings.notifies_CI_Failure
            )
            Toggle(
                "When a server stops responding for 1 min",
                isOn: $model.alert_Settings.notifies_Server_Down
            )
        }
    }

    private var sustain_Seconds: Int {
        Int(model.alert_Settings.sustain_Seconds)
    }

    private var cooldown_Minutes: Int {
        Int(model.alert_Settings.cooldown_Seconds / 60)
    }
}

struct AlertRuleRow: View {
    static let SLIDER_WIDTH: CGFloat = 170
    static let VALUE_WIDTH: CGFloat = 56

    @Binding var rule: AlertRule

    var body: some View {
        HStack {
            Toggle(
                AlertMessage.describeName(rule.metric),
                isOn: $rule.is_Enabled
            )
            Spacer()
            Slider(
                value: $rule.limit,
                in: rule.metric.limit_Range,
                step: rule.metric.limit_Step
            )
            .frame(width: Self.SLIDER_WIDTH)
            .disabled(!rule.is_Enabled)
            Text(
                AlertMessage.describeValue(
                    rule.limit,
                    of: rule.metric
                )
            )
            .monospacedDigit()
            .frame(width: Self.VALUE_WIDTH, alignment: .trailing)
        }
    }
}
