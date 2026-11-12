import AppKit
import DevWidgetsCore
import Foundation
import Observation

/// Shows the developer context: `DeveloperContextRefresher` (shared
/// with the Linux app) reads it off the main thread; this model
/// keeps the latest, publishes it for the widgets and notifies
/// failed CI.
@MainActor
@Observable
final class DeveloperContextModel {
    static let PROJECT_FOLDER_KEY = "projectFolderPath"

    private(set) var latest_Context: DeveloperContext?

    @ObservationIgnored
    private var publisher = ContextPublisher(
        store: AppGroup.makeContextStore()
    )
    @ObservationIgnored
    private let refresher = DeveloperContextRefresher(
        github_Client: DeveloperContextModel.makeClient()
    )
    /// Lets a refresh that finishes after a newer one be dropped.
    @ObservationIgnored
    private var refresh_Count = 0

    /// The folder whose Git status is shown, remembered across
    /// launches. The app is not sandboxed, so a path is enough.
    var project_URL: URL? {
        get {
            UserDefaults.standard
                .string(forKey: Self.PROJECT_FOLDER_KEY)
                .map { URL(fileURLWithPath: $0) }
        }
        set {
            UserDefaults.standard.set(
                newValue?.path,
                forKey: Self.PROJECT_FOLDER_KEY
            )
        }
    }

    static func makeClient() -> GitHubClient? {
        let host_Text = UserDefaults.standard.string(
            forKey: GitHubHost.SETTING_KEY
        )
        return GitHubTransportChoice.choose(
            token: GitHubTokenStore.readToken(),
            host: GitHubHost(text: host_Text ?? "")
        ).map { GitHubClient(transport: $0) }
    }

    /// Runs until the surrounding task is cancelled.
    func runRefreshLoop() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(
                for: .seconds(DeveloperContextReader.INTERVAL_SECONDS)
            )
        }
    }

    func refresh() async {
        refresh_Count += 1
        let this_Refresh = refresh_Count
        let refresh = await refresher.refresh(
            project_URL: project_URL
        )
        guard this_Refresh == refresh_Count else { return }
        latest_Context = refresh.context
        publisher.publish(refresh.context)
        notifyFailedCI(refresh.ci_Alert)
    }

    private func notifyFailedCI(_ alert: CIFailureAlert?) {
        guard AlertSettingsStore.load().notifies_CI_Failure,
            let alert
        else { return }
        UserNotifier.SHARED.post(
            alert.message,
            identifier: alert.identifier,
            page_URL: alert.page_URL
        )
    }

    /// After the token changed: a new client, asked right away.
    func resetGitHub() {
        Task {
            await refresher.replaceClient(Self.makeClient())
            await refresh()
        }
    }

    func chooseProject() {
        let open_Panel = NSOpenPanel()
        open_Panel.canChooseDirectories = true
        open_Panel.canChooseFiles = false
        open_Panel.prompt = String(localized: "Show Git Status")
        NSApplication.shared.activate()
        guard open_Panel.runModal() == .OK,
            let folder_URL = open_Panel.url
        else { return }
        project_URL = folder_URL
        Task { await refresh() }
    }
}
