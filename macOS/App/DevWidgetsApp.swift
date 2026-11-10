import SwiftUI

/// Menu bar host app. It samples the machine every second, reads
/// the developer context every few seconds and the servers every
/// 15, shows them in its panel, publishes them for the widgets,
/// alerts on thresholds and failed CI, and performs the actions
/// widgets ask for. It starts at login after the first launch.
@main
struct DevWidgetsApp: App {
    @State private var live_Metrics: LiveMetricsModel
    @State private var developer_Context: DeveloperContextModel
    @State private var action_Handler: ActionHandler
    @State private var servers: ServersModel

    /// The loops start here, not in a view's `.task`, so sampling
    /// does not depend on macOS showing the menu bar item.
    init() {
        let metrics_Model = LiveMetricsModel()
        let context_Model = DeveloperContextModel()
        let handler = ActionHandler(context_Model: context_Model)
        let servers_Model = ServersModel()
        _live_Metrics = State(initialValue: metrics_Model)
        _developer_Context = State(initialValue: context_Model)
        _action_Handler = State(initialValue: handler)
        _servers = State(initialValue: servers_Model)
        LoginItem.registerOnFirstLaunch()
        Task { await UserNotifier.SHARED.requestAuthorization() }
        Task { await metrics_Model.runSamplingLoop() }
        Task { await context_Model.runRefreshLoop() }
        Task { await handler.runInboxLoop() }
        Task { await servers_Model.runPollingLoop() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(
                model: live_Metrics,
                context_Model: developer_Context,
                servers_Model: servers,
                handler: action_Handler
            )
        } label: {
            MenuBarLabel(snapshot: live_Metrics.latest_Snapshot)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView(
                metrics_Model: live_Metrics,
                context_Model: developer_Context,
                servers_Model: servers
            )
        }
    }
}
