import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import Foundation

/// What the preferences need from the app.
struct PreferencesHandlers {
    /// Saves and applies at once, as GNOME settings do.
    let save: (LinuxSettings) -> Void
    let choose_Project: (@escaping (URL?) -> Void) -> Void
    /// "GITHUB_TOKEN from the environment", "gh command"...
    let github_Source_Text: String
}

/// Alerts, servers, and project & GitHub, in an
/// AdwPreferencesDialog. The GTK signal closures own this object,
/// so it lives exactly as long as the dialog.
final class PreferencesDialog {
    private let dialog = created(adw_preferences_dialog_new())
    private let handlers: PreferencesHandlers
    var settings: LinuxSettings
    let servers_Page = created(adw_preferences_page_new())
    var hosts_Group: WidgetPointer?
    var suggestions_Group: WidgetPointer?
    let alias_Row = PreferenceRows.makeEntryRow("SSH alias")
    let disk_Row = PreferenceRows.makeEntryRow(
        "Disk to measure",
        text: RemoteHost.DEFAULT_DISK_PATH
    )

    init(settings: LinuxSettings, handlers: PreferencesHandlers) {
        self.settings = settings
        self.handlers = handlers
        adw_dialog_set_title(castPointer(dialog), "Preferences")
        addPage(
            makeAlertsPage(),
            title: "Alerts",
            icon_Name: "dialog-warning-symbolic"
        )
        configureServersPage()
        addPage(
            servers_Page,
            title: "Servers",
            icon_Name: "network-server-symbolic"
        )
        addPage(
            makeProjectPage(),
            title: "Project & GitHub",
            icon_Name: "folder-open-symbolic"
        )
    }

    func present(parent: WidgetPointer) {
        adw_dialog_present(castPointer(dialog), parent)
    }

    /// Picks the page shown first (used for the captures).
    func showPage(named title: String) {
        adw_preferences_dialog_set_visible_page_name(
            castPointer(dialog),
            title
        )
    }

    private func addPage(
        _ page: WidgetPointer,
        title: String,
        icon_Name: String
    ) {
        adw_preferences_page_set_title(castPointer(page), title)
        adw_preferences_page_set_icon_name(
            castPointer(page),
            icon_Name
        )
        adw_preferences_page_set_name(castPointer(page), title)
        adw_preferences_dialog_add(
            castPointer(dialog),
            castPointer(page)
        )
    }

    func update(_ change: (inout LinuxSettings) -> Void) {
        change(&settings)
        handlers.save(settings)
    }

    func showToast(_ text: String) {
        adw_preferences_dialog_add_toast(
            castPointer(dialog),
            adw_toast_new(text)
        )
    }
}

// MARK: - Alerts

extension PreferencesDialog {
    private func makeAlertsPage() -> WidgetPointer {
        let alert_Settings = settings.alert_Settings
        let limits_Group = PreferenceRows.makeGroup(
            "Limits",
            description: Self.describeTiming(alert_Settings)
        )
        for rule in alert_Settings.rules {
            let row = PreferenceRows.makeRuleRow(rule) { [self] in
                replaceRule($0)
            }
            PreferenceRows.add(row, to: limits_Group)
        }
        return PreferenceRows.makePage([
            limits_Group, makeEventsGroup(),
        ])
    }

    /// "A reading must stay past its limit for 30 s; ...".
    static func describeTiming(
        _ alert_Settings: AlertSettings
    ) -> String {
        let sustain_Seconds = Int(alert_Settings.sustain_Seconds)
        let cooldown_Minutes = Int(
            alert_Settings.cooldown_Seconds / 60
        )
        return "A reading must stay past its limit for"
            + " \(sustain_Seconds) s; one alert per metric every"
            + " \(cooldown_Minutes) min at most."
    }

    private func replaceRule(_ new_Rule: AlertRule) {
        update { settings in
            let rules = settings.alert_Settings.rules
            settings.alert_Settings.rules = rules.map {
                $0.metric == new_Rule.metric ? new_Rule : $0
            }
        }
    }

    private func makeEventsGroup() -> WidgetPointer {
        let group = PreferenceRows.makeGroup("Events")
        let alert_Settings = settings.alert_Settings
        let ci_Row = PreferenceRows.makeSwitchRow(
            "When the project's branch CI fails",
            is_On: alert_Settings.notifies_CI_Failure
        ) { [self] is_On in
            update { $0.alert_Settings.notifies_CI_Failure = is_On }
        }
        let server_Row = PreferenceRows.makeSwitchRow(
            "When a server stops responding for 1 min",
            is_On: alert_Settings.notifies_Server_Down
        ) { [self] is_On in
            update { $0.alert_Settings.notifies_Server_Down = is_On }
        }
        PreferenceRows.add(ci_Row, to: group)
        PreferenceRows.add(server_Row, to: group)
        return group
    }
}

// MARK: - Project & GitHub

extension PreferencesDialog {
    private func makeProjectPage() -> WidgetPointer {
        let github_Group = PreferenceRows.makeGroup(
            "GitHub",
            description: "Set GITHUB_TOKEN or sign in with gh; the"
                + " Linux app keeps no token of its own."
        )
        PreferenceRows.add(
            PreferenceRows.makeActionRow(
                "Source",
                subtitle: handlers.github_Source_Text
            ),
            to: github_Group
        )
        return PreferenceRows.makePage([
            makeProjectGroup(), github_Group,
        ])
    }

    private func makeProjectGroup() -> WidgetPointer {
        let group = PreferenceRows.makeGroup("Project")
        let project_Row = PreferenceRows.makeActionRow(
            "Project folder",
            subtitle: settings.project_Path ?? "None chosen"
        )
        let choose_Button = Buttons.makeTextButton("Choose…") {
            [self] in
            handlers.choose_Project { [self] folder in
                guard let folder else { return }
                adw_action_row_set_subtitle(
                    castPointer(project_Row),
                    folder.path
                )
                update { $0.project_Path = folder.path }
            }
        }
        adw_action_row_add_suffix(
            castPointer(project_Row),
            choose_Button
        )
        PreferenceRows.add(project_Row, to: group)
        return group
    }
}
