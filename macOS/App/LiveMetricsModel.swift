import DevWidgetsCore
import DevWidgetsDarwin
import Foundation
import Observation

/// Owns the sampling loop, the state the menu bar shows and the
/// threshold alerts, which are checked on every sample.
@MainActor
@Observable
final class LiveMetricsModel {
    static let SAMPLE_INTERVAL: Duration = .seconds(1)

    private(set) var latest_Snapshot: MetricSnapshot?
    private(set) var last_Error_Text: String?
    /// Shown in the panel while the widgets get no data.
    private(set) var widget_Problem_Text: String?
    /// Edited live by the Settings window.
    var alert_Settings = AlertSettingsStore.load() {
        didSet { AlertSettingsStore.save(alert_Settings) }
    }

    @ObservationIgnored
    private var monitor = MetricsMonitor(reader: DarwinSampleReader())
    @ObservationIgnored
    private var publisher = WidgetPublisher(
        store: AppGroup.makeSnapshotStore()
    )
    @ObservationIgnored
    private var alert_Monitor = AlertMonitor()

    /// Runs until the surrounding task is cancelled.
    func runSamplingLoop() async {
        while !Task.isCancelled {
            sampleOnce()
            try? await Task.sleep(for: Self.SAMPLE_INTERVAL)
        }
    }

    private func sampleOnce() {
        do {
            guard let snapshot = try monitor.sample() else { return }
            latest_Snapshot = snapshot
            last_Error_Text = nil
            publisher.publishIfDue(snapshot)
            if widget_Problem_Text != publisher.problem_Text {
                widget_Problem_Text = publisher.problem_Text
            }
            notifyAlerts(for: snapshot)
        } catch {
            last_Error_Text = String(describing: error)
        }
    }

    private func notifyAlerts(for snapshot: MetricSnapshot) {
        let alerts = alert_Monitor.evaluate(
            snapshot.readings,
            settings: alert_Settings,
            at: snapshot.captured_At
        )
        for alert in alerts {
            UserNotifier.SHARED.post(
                AlertMessage(alert: alert, settings: alert_Settings),
                identifier: "alert.\(alert.rule.metric.rawValue)"
            )
        }
    }
}
