import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import Foundation

/// The readers behind the context and servers loops.
struct ContextSources {
    let refresher: DeveloperContextRefresher
    let ssh_Reader: SSHReader
    let github_Source_Text: String

    init() {
        let token = GitHubSource.readToken()
        let gh_URL = ExecutableSearch.locate("gh")
        let client = GitHubTransportChoice.choose(
            token: token,
            host: GitHubSource.readHost(),
            gh_URL: gh_URL
        ).map { GitHubClient(transport: $0) }
        refresher = DeveloperContextRefresher(
            reader: DeveloperContextReader(),
            github_Client: client
        )
        var ssh_Reader = SSHReader()
        ssh_Reader.options.control_Directory =
            SSHConnectionSharing.prepareDirectory()
        self.ssh_Reader = ssh_Reader
        github_Source_Text = GitHubSource.describe(
            token: token,
            gh_URL: gh_URL
        )
    }
}

/// Sampling every second, context every 10 s, servers every 15 s.
/// A slow round is never started twice.
extension LinuxApp {
    func startLoops() {
        let context_Milliseconds = UInt32(
            DeveloperContextReader.INTERVAL_SECONDS * 1_000
        )
        let servers_Milliseconds = UInt32(
            RemoteTracker.INTERVAL_SECONDS * 1_000
        )
        MainLoop.repeatEvery(milliseconds: Self.SAMPLE_MILLISECONDS) {
            [unowned self] in sample()
        }
        MainLoop.repeatEvery(milliseconds: context_Milliseconds) {
            [unowned self] in refreshContext()
        }
        MainLoop.repeatEvery(milliseconds: servers_Milliseconds) {
            [unowned self] in pollServers()
        }
        sample()
        refreshContext()
        pollServers()
    }

    private func sample() {
        sample_Worker.sample { [unowned self] snapshot in
            window?.show(snapshot)
            tray?.update(TrayState(readings: snapshot.readings))
            send(
                router.route(
                    snapshot,
                    settings: settings.alert_Settings
                )
            )
        }
    }

    func refreshContext() {
        guard !is_Refreshing_Context else { return }
        is_Refreshing_Context = true
        let refresher = sources.refresher
        let project_URL = settings.project_URL
        Task.detached { [unowned self] in
            let refresh = await refresher.refresh(
                project_URL: project_URL
            )
            MainLoop.post { [unowned self] in showContext(refresh) }
        }
    }

    private func showContext(_ refresh: ContextRefresh) {
        is_Refreshing_Context = false
        window?.show(refresh.context)
        send(
            router.route(
                refresh.ci_Alert,
                settings: settings.alert_Settings
            )
        )
    }

    func pollServers() {
        guard !is_Polling_Servers else { return }
        is_Polling_Servers = true
        let hosts = settings.hosts
        let reader = sources.ssh_Reader
        Task.detached { [unowned self] in
            let results = await reader.readAll(hosts)
            MainLoop.post { [unowned self] in
                showServers(hosts: hosts, results: results)
            }
        }
    }

    private func showServers(
        hosts: [RemoteHost],
        results: [RemoteHost: Result<RemoteSnapshot, RemoteProblem>]
    ) {
        is_Polling_Servers = false
        let overview = tracker.update(hosts: hosts, results: results)
        window?.show(overview)
        send(
            router.route(overview, settings: settings.alert_Settings)
        )
    }

    private func send(_ notifications: [DesktopNotification]) {
        notifications.forEach { notifier?.send($0) }
    }
}

/// Confirmation, actions and dialogs.
extension LinuxApp {
    func confirmAndRun(_ action: WidgetAction) {
        guard let window else { return }
        guard action.needs_Confirmation else {
            return perform(action)
        }
        Dialogs.confirm(action, parent: window.window) {
            [unowned self] in
            perform(action)
        }
    }

    private func perform(_ action: WidgetAction) {
        ActionRunner.run(action, project_URL: settings.project_URL) {
            [unowned self] outcome in
            let failure = outcome.describeFailure(of: action)
            window?.showToast(
                failure.map { "\($0.title): \($0.body)" }
                    ?? "\(action.title): done"
            )
            refreshContext()
        }
    }

    func chooseProject(_ chosen: @escaping (URL?) -> Void = { _ in })
    {
        guard let window else { return }
        Dialogs.chooseFolder(parent: window.window) {
            [unowned self] folder in
            if let folder {
                var new_Settings = settings
                new_Settings.project_Path = folder.path
                saveSettings(new_Settings)
            }
            chosen(folder)
        }
    }

    func openPreferences(_ page: String) {
        guard let window else { return }
        let dialog = PreferencesDialog(
            settings: settings,
            handlers: PreferencesHandlers(
                save: { [unowned self] in saveSettings($0) },
                choose_Project: { [unowned self] in chooseProject($0)
                },
                github_Source_Text: sources.github_Source_Text
            )
        )
        dialog.showPage(named: page)
        dialog.present(parent: window.window)
    }
}
