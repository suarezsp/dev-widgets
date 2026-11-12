import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import DevWidgetsPresentation
import Foundation

/// The Servers page: monitored hosts, a form to add one with its
/// disk, and the aliases found in ~/.ssh/config (Includes too).
extension PreferencesDialog {
    static let ADD_DESCRIPTION = String(
        localized: """
            An alias from ~/.ssh/config; ssh keeps the keys. \
            The disk is a mount point on the server.
            """
    )

    func configureServersPage() {
        let add_Group = PreferenceRows.makeGroup(
            String(localized: "Add a server"),
            description: Self.ADD_DESCRIPTION
        )
        let add_Button = Buttons.makeTextButton(
            String(localized: "Add")
        ) { [self] in
            addHost(
                alias: PreferenceRows.readText(alias_Row),
                disk_Path: PreferenceRows.readText(disk_Row)
            )
        }
        Widgets.addClasses(add_Button, ["suggested-action"])
        PreferenceRows.add(alias_Row, to: add_Group)
        adw_entry_row_add_suffix(castPointer(disk_Row), add_Button)
        PreferenceRows.add(disk_Row, to: add_Group)
        adw_preferences_page_add(
            castPointer(servers_Page),
            castPointer(add_Group)
        )
        rebuildServerGroups()
    }

    private func addHost(alias: String, disk_Path: String) {
        let path =
            disk_Path.isEmpty
            ? RemoteHost.DEFAULT_DISK_PATH : disk_Path
        guard let host = RemoteHost(alias: alias, disk_Path: path)
        else {
            showToast(
                String(localized: "Not a valid alias or disk path")
            )
            return
        }
        guard !settings.hosts.contains(where: { $0.alias == alias })
        else {
            showToast("\(alias) is already monitored")
            return
        }
        update { $0.hosts.append(host) }
        gtk_editable_set_text(castPointer(alias_Row), "")
        rebuildServerGroups()
    }

    private func removeHost(_ host: RemoteHost) {
        update { $0.hosts.removeAll { $0 == host } }
        rebuildServerGroups()
    }

    /// The two lists change together: adding a suggestion moves it.
    func rebuildServerGroups() {
        for group in [hosts_Group, suggestions_Group].compactMap({
            $0
        }) {
            adw_preferences_page_remove(
                castPointer(servers_Page),
                castPointer(group)
            )
        }
        let new_Hosts_Group = makeHostsGroup()
        let new_Suggestions_Group = makeSuggestionsGroup()
        for group in [new_Hosts_Group, new_Suggestions_Group] {
            adw_preferences_page_add(
                castPointer(servers_Page),
                castPointer(group)
            )
        }
        hosts_Group = new_Hosts_Group
        suggestions_Group = new_Suggestions_Group
    }

    private func makeHostsGroup() -> WidgetPointer {
        let group = PreferenceRows.makeGroup(
            String(localized: "Monitored")
        )
        var rows = settings.hosts.map(makeHostRow)
        if rows.isEmpty {
            rows = [
                PreferenceRows.makeActionRow(
                    String(localized: "No servers yet"),
                    subtitle: ""
                )
            ]
        }
        rows.forEach { PreferenceRows.add($0, to: group) }
        return group
    }

    private func makeHostRow(_ host: RemoteHost) -> WidgetPointer {
        let remove_Button = Buttons.makeIconButton(
            "user-trash-symbolic",
            tooltip_Text: String(
                localized: "Stop monitoring \(host.alias)"
            )
        ) { [self] in removeHost(host) }
        return PreferenceRows.makeActionRow(
            host.alias,
            subtitle: String(localized: "Disk \(host.disk_Path)"),
            suffix: remove_Button
        )
    }

    private func makeSuggestionsGroup() -> WidgetPointer {
        let group = PreferenceRows.makeGroup(
            String(localized: "From ~/.ssh/config"),
            description: String(
                localized: "Include lines are followed."
            )
        )
        let monitored = Set(settings.hosts.map(\.alias))
        SSHConfigReader().listAliases()
            .filter { !monitored.contains($0) }
            .map(makeSuggestionRow)
            .forEach { PreferenceRows.add($0, to: group) }
        return group
    }

    private func makeSuggestionRow(_ alias: String) -> WidgetPointer {
        let add_Button = Buttons.makeIconButton(
            "list-add-symbolic",
            tooltip_Text: String(localized: "Monitor \(alias)")
        ) { [self] in
            addHost(
                alias: alias,
                disk_Path: RemoteHost.DEFAULT_DISK_PATH
            )
        }
        return PreferenceRows.makeActionRow(
            alias,
            subtitle: "",
            suffix: add_Button
        )
    }
}
