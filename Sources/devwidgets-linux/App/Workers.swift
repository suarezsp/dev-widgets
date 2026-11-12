import DevWidgetsCore
import DevWidgetsLinuxShell
import DevWidgetsPresentation
import Foundation

/// Reads the machine off the GTK thread: walking /proc for every
/// process takes tens of milliseconds.
final class SampleWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "devwidgets.sampling")
    // Only touched on `queue`.
    private var monitor = MetricsMonitor(reader: LinuxSampleReader())

    func sample(_ done: @escaping (MetricSnapshot) -> Void) {
        queue.async { [self] in
            guard let snapshot = try? monitor.sample() else { return }
            MainLoop.post { done(snapshot) }
        }
    }
}

/// Confirmed actions, run off the GTK thread (Docker can take
/// ten seconds to stop a container).
enum ActionRunner {
    static func run(
        _ action: WidgetAction,
        project_URL: URL?,
        done: @escaping (ActionOutcome) -> Void
    ) {
        Task.detached {
            let outcome = await execute(
                action,
                project_URL: project_URL
            )
            MainLoop.post { done(outcome) }
        }
    }

    static func execute(
        _ action: WidgetAction,
        project_URL: URL?
    ) async -> ActionOutcome {
        switch action {
        case .open_Project:
            return openProject(project_URL)
        case .terminate_Process(let process):
            return ProcessTerminator(name_Lookup: {
                LinuxProcessReader.readName(of: $0)
            }).terminate(process)
        case .stop_Container(let container):
            return await ContainerController(
                runner: ProcessCommandRunner()
            ).stop(container)
        case .restart_Container(let container):
            return await ContainerController(
                runner: ProcessCommandRunner()
            ).restart(container)
        }
    }

    static func openProject(_ project_URL: URL?) -> ActionOutcome {
        guard let project_URL else {
            return .refused(
                reason: String(
                    localized: "Choose a project folder first"
                )
            )
        }
        URLOpener.open(project_URL)
        return .done
    }
}
