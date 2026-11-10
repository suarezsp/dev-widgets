import DevWidgetsCore
import DevWidgetsDarwin
import Foundation

/// Performs what widgets and the panel ask for, in the menu bar
/// app, which (unlike the widget extension) may signal processes
/// and run `docker`. Woken by `ActionSignal`; it also checks the
/// inbox every few seconds in case a signal was missed.
@MainActor
final class ActionHandler {
    static let POLL_INTERVAL: Duration = .seconds(5)

    private let context_Model: DeveloperContextModel
    private var signal_Token: Int32 = 0

    init(context_Model: DeveloperContextModel) {
        self.context_Model = context_Model
    }

    /// Runs until the surrounding task is cancelled.
    func runInboxLoop() async {
        signal_Token = ActionSignal.observe { [weak self] in
            Task { await self?.handlePending() }
        }
        while !Task.isCancelled {
            await handlePending()
            try? await Task.sleep(for: Self.POLL_INTERVAL)
        }
    }

    func handlePending() async {
        for action in AppGroup.makeActionInbox()?.drain() ?? [] {
            await perform(action)
        }
    }

    /// Failures and refusals are reported as notifications: a
    /// widget tap has no other way to answer.
    func perform(_ action: WidgetAction) async {
        let outcome = await Self.execute(
            action,
            project_URL: context_Model.project_URL
        )
        if let message = outcome.describeFailure(of: action) {
            UserNotifier.SHARED.post(message, identifier: "action")
        }
        await context_Model.refresh()
    }

    static func execute(
        _ action: WidgetAction,
        project_URL: URL?
    ) async -> ActionOutcome {
        switch action {
        case .open_Project:
            return ProjectOpener.open(project_URL)
        case .terminate_Process(let process):
            return ProcessTerminator(
                name_Lookup: DarwinProcessNames.readName
            ).terminate(process)
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
}
