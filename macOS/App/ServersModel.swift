import DevWidgetsCore
import Foundation
import Observation
import WidgetKit

/// Polls the user's servers over SSH every 15 seconds, all hosts in
/// parallel and off the main thread, and publishes the overview for
/// the panel and the servers widget.
@MainActor
@Observable
final class ServersModel {
    static let HOSTS_KEY = "remoteHosts"

    private(set) var overview = ServerOverview(reports: [])
    /// Edited by the Settings window; saved as JSON.
    var hosts: [RemoteHost] = ServersModel.loadHosts() {
        didSet {
            saveHosts()
            Task { await poll() }
        }
    }

    @ObservationIgnored
    private var tracker = RemoteTracker()
    @ObservationIgnored
    private var publisher = ServerPublisher(
        store: AppGroup.makeServerStore()
    )
    @ObservationIgnored
    private let reader = ServersModel.makeReader()
    @ObservationIgnored
    private var down_Monitor = ServerDownMonitor()

    static func makeReader() -> SSHReader {
        var reader = SSHReader()
        reader.options.control_Directory =
            SSHConnectionSharing.prepareDirectory()
        return reader
    }

    /// Runs until the surrounding task is cancelled.
    func runPollingLoop() async {
        while !Task.isCancelled {
            await poll()
            try? await Task.sleep(
                for: .seconds(RemoteTracker.INTERVAL_SECONDS)
            )
        }
    }

    func poll() async {
        let polled_Hosts = hosts
        let results = await reader.readAll(polled_Hosts)
        // Hosts edited meanwhile: the next poll covers them.
        guard polled_Hosts == hosts else { return }
        overview = tracker.update(
            hosts: polled_Hosts,
            results: results
        )
        publisher.publish(overview)
        notifyServersDown()
    }

    /// The monitor always runs so its timing stays right; only the
    /// notification depends on the setting.
    private func notifyServersDown() {
        let alerts = down_Monitor.evaluate(overview, at: Date())
        guard AlertSettingsStore.load().notifies_Server_Down else {
            return
        }
        for alert in alerts {
            UserNotifier.SHARED.post(
                alert.message,
                identifier: alert.identifier
            )
        }
    }

    /// Aliases from `~/.ssh/config` and the files it includes,
    /// not monitored yet.
    func suggestAliases() -> [String] {
        SSHConfigReader().listAliases().filter { alias in
            !hosts.contains { $0.alias == alias }
        }
    }

    static func loadHosts() -> [RemoteHost] {
        guard
            let hosts_Data = UserDefaults.standard.data(
                forKey: HOSTS_KEY
            )
        else { return [] }
        return
            (try? JSONDecoder().decode(
                [RemoteHost].self,
                from: hosts_Data
            )) ?? []
    }

    private func saveHosts() {
        let hosts_Data = try? JSONEncoder().encode(hosts)
        UserDefaults.standard.set(hosts_Data, forKey: Self.HOSTS_KEY)
    }
}

/// Saves every overview for the widget; reloads the servers widget
/// only when a host goes up or down or changes colour.
struct ServerPublisher {
    private let store: ServerStore?
    private var reload_Throttle = ReloadThrottle<ServerShape>(
        min_Reload_Seconds: ServerShape.MIN_RELOAD_SECONDS
    )

    init(store: ServerStore?) {
        self.store = store
    }

    mutating func publish(_ overview: ServerOverview) {
        guard let store, (try? store.save(overview)) != nil else {
            return
        }
        guard
            reload_Throttle.shouldReload(
                for: ServerShape(overview),
                at: Date()
            )
        else { return }
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppGroup.SERVERS_KIND
        )
    }
}
