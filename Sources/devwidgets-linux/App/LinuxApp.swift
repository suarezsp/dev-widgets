import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import Foundation

/// Owns the window, the tray icon and the polling loops, and
/// routes every reading through the shared alert logic.
final class LinuxApp {
    static let APPLICATION_ID = "com.morsetechnologies.DevWidgets"
    static let SAMPLE_MILLISECONDS: UInt32 = 1_000

    let application: OpaquePointer
    let options: LaunchOptions
    let store = LinuxSettingsStore()
    var settings: LinuxSettings
    var window: DashboardWindow?
    var notifier: DesktopNotifier?
    var tray: StatusNotifier?
    var router = AlertRouter()
    let sample_Worker = SampleWorker()
    let sources = ContextSources()
    var tracker = RemoteTracker()
    var is_Refreshing_Context = false
    var is_Polling_Servers = false
    var is_Held = false

    init(options: LaunchOptions) {
        self.options = options
        settings = store.load()
        g_set_application_name(TrayState.TITLE)
        application = castPointer(
            adw_application_new(
                Self.APPLICATION_ID,
                G_APPLICATION_DEFAULT_FLAGS
            )
        )
        Signals.connect(
            UnsafeMutableRawPointer(application),
            "activate"
        ) { [self] in activate() }
    }

    func run() -> Int32 {
        var arguments = [
            strdup(CommandLine.arguments.first ?? "devwidgets")
        ]
        defer { arguments.forEach { free($0) } }
        return g_application_run(
            castPointer(application),
            1,
            &arguments
        )
    }

    /// Also called when the app is launched a second time.
    private func activate() {
        if let window {
            window.present()
            return
        }
        Appearance.apply(options.color_Scheme)
        let window = DashboardWindow(
            application: application,
            handlers: makeWindowHandlers()
        )
        self.window = window
        notifier = DesktopNotifier(application: application) {
            [unowned self] in self.window?.present()
        }
        startTray()
        startLoops()
        if !options.starts_Hidden { window.present() }
        if let page = options.preferences_Page {
            openPreferences(page)
        }
    }

    private func makeWindowHandlers() -> WindowHandlers {
        WindowHandlers(
            cards: CardHandlers(
                request: { [unowned self] in confirmAndRun($0) },
                open: { URLOpener.open($0) }
            ),
            choose_Project: { [unowned self] in chooseProject() },
            open_Preferences: { [unowned self] in
                openPreferences("Alerts")
            }
        )
    }

    /// A panel without a tray watcher would leave a hidden window
    /// unreachable, so closing hides only once the icon is shown.
    private func startTray() {
        let icon_Path = Appearance.installIconPath()
        let tray = StatusNotifier(
            properties: TrayProperties(
                icon_Theme_Path: icon_Path ?? ""
            )
        ) { [unowned self] in window?.toggle() }
        tray.on_Registered = { [unowned self] in keepRunningInTray() }
        tray.menu = TrayMenu { [unowned self] in chooseFromTray($0) }
        tray.start()
        self.tray = tray
    }

    private func chooseFromTray(_ item: TrayMenuItem) {
        switch item {
        case .toggle_Window: window?.toggle()
        case .preferences:
            window?.present()
            openPreferences("Alerts")
        case .quit: g_application_quit(castPointer(application))
        case .separator: break
        }
    }

    private func keepRunningInTray() {
        guard let window, !is_Held else { return }
        is_Held = true
        gtk_window_set_hide_on_close(castPointer(window.window), 1)
        g_application_hold(castPointer(application))
    }

    func saveSettings(_ new_Settings: LinuxSettings) {
        let old_Settings = settings
        settings = new_Settings
        do {
            try store.save(new_Settings)
        } catch {
            window?.showToast("Could not save the settings")
        }
        if old_Settings.hosts != new_Settings.hosts { pollServers() }
        if old_Settings.project_Path != new_Settings.project_Path {
            refreshContext()
        }
    }
}
