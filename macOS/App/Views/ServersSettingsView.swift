import DevWidgetsCore
import SwiftUI

/// Servers by their `~/.ssh/config` alias. DevWidgets stores no
/// password or key: the system `ssh` and its agent do the login.
struct ServersSettingsView: View {
    @Bindable var model: ServersModel

    @State private var alias_Text = ""
    @State private var disk_Text = RemoteHost.DEFAULT_DISK_PATH

    var body: some View {
        Form {
            Section {
                Text(
                    "DevWidgets runs ssh with your own config and"
                        + " keys, never asks for a password and only"
                        + " reads /proc. The host must be Linux."
                )
                .foregroundStyle(.secondary)
            }
            monitored_Section
            add_Section
            suggestions_Section
        }
        .formStyle(.grouped)
    }

    private var monitored_Section: some View {
        Section("Monitored") {
            ForEach(model.hosts, id: \.self) { host in
                HStack {
                    ServerRow(report: findReport(host))
                    Text(host.disk_Path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Remove", role: .destructive) {
                        model.hosts.removeAll { $0 == host }
                    }
                }
            }
        }
    }

    private var add_Section: some View {
        Section("Add") {
            HStack {
                TextField("Alias or user@host", text: $alias_Text)
                    .onSubmit { addHost(alias_Text) }
                TextField("Disk", text: $disk_Text)
                    .frame(width: 120)
                Button("Add") { addHost(alias_Text) }
                    .disabled(
                        RemoteHost(
                            alias: alias_Text,
                            disk_Path: disk_Text
                        ) == nil
                    )
            }
        }
    }

    /// Aliases from ~/.ssh/config and its Include files.
    @ViewBuilder private var suggestions_Section: some View {
        let suggestions = model.suggestAliases()
        if !suggestions.isEmpty {
            Section("From ~/.ssh/config") {
                ForEach(suggestions, id: \.self) { alias in
                    Button(alias) { addHost(alias) }
                        .buttonStyle(.link)
                }
            }
        }
    }

    /// A host added a moment ago has no poll yet.
    private func findReport(_ host: RemoteHost) -> RemoteHostReport {
        model.overview.reports.first { $0.host == host }
            ?? RemoteHostReport(host: host, state: .not_Loaded)
    }

    private func addHost(_ alias: String) {
        guard
            let host = RemoteHost(alias: alias, disk_Path: disk_Text),
            !model.hosts.contains(host)
        else { return }
        model.hosts.append(host)
        alias_Text = ""
    }
}
