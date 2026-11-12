import DevWidgetsCore
import SwiftUI

/// Token in the Keychain, or `gh` when there is none.
struct GitHubSettingsView: View {
    let context_Model: DeveloperContextModel

    @State private var token_Text = ""
    @State private var has_Token = GitHubTokenStore.readToken() != nil
    @State private var error_Text: String?
    @AppStorage(GitHubHost.SETTING_KEY) private var host_Text = ""

    var body: some View {
        Form {
            Section {
                Text(
                    """
                    CI and pull request of the project's branch, and \
                    pull requests awaiting your review. DevWidgets \
                    uses the token below if you save one, otherwise \
                    the gh command (run gh auth login once).
                    """
                )
                .foregroundStyle(.secondary)
            }
            token_Section
            host_Section
            Section("Now") {
                GitHubRow(
                    github: context_Model.latest_Context?.github
                        ?? .not_Configured
                )
            }
        }
        .formStyle(.grouped)
    }

    private var token_Section: some View {
        Section("Personal access token") {
            SecureField("github_pat_…", text: $token_Text)
            HStack {
                Button("Save to Keychain") { saveToken() }
                    .disabled(token_Text.isEmpty)
                if has_Token {
                    Button("Remove", role: .destructive) {
                        removeToken()
                    }
                }
                Spacer()
                Text(has_Token ? "Token saved" : "No token")
                    .foregroundStyle(.secondary)
            }
            token_Hint
            if let error_Text {
                Text(error_Text).foregroundStyle(.red)
            }
        }
    }

    private var host_Section: some View {
        Section("Host") {
            TextField("github.com", text: $host_Text)
                .onSubmit { context_Model.resetGitHub() }
            Text(
                """
                Leave empty for github.com. For GitHub Enterprise \
                Server, type its host and press Return; the token, \
                or gh auth login --hostname, must be for that host.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var token_Hint: some View {
        Text(
            """
            Read-only is enough: a fine-grained token with Actions \
            and Pull requests set to Read. Reviews only list \
            repositories the token can read.
            """
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func saveToken() {
        do {
            try GitHubTokenStore.saveToken(token_Text)
            token_Text = ""
            has_Token = true
            error_Text = nil
            context_Model.resetGitHub()
        } catch {
            let reason = String(describing: error)
            error_Text = String(
                localized: "The Keychain refused the token: \(reason)"
            )
        }
    }

    private func removeToken() {
        GitHubTokenStore.deleteToken()
        has_Token = false
        context_Model.resetGitHub()
    }
}

/// Which app "Open Project" uses.
struct EditorSettingsView: View {
    @AppStorage(ProjectOpener.EDITOR_KEY)
    private var editor_Bundle_ID = ""

    var body: some View {
        Form {
            Picker("Open projects with", selection: $editor_Bundle_ID)
            {
                Text("Automatic").tag("")
                ForEach(
                    ProjectOpener.installedEditors(),
                    id: \.bundle_ID
                ) {
                    Text($0.name).tag($0.bundle_ID)
                }
            }
            Text(
                """
                Automatic tries Cursor, Visual Studio Code, Zed and \
                Xcode, then Finder.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
