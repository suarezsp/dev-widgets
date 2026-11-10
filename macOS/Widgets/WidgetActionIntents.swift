import AppIntents
import DevWidgetsCore
import WidgetKit

/// Runs inside the sandboxed widget extension, which may neither
/// signal other processes nor launch `docker`: it only records the
/// request for the menu bar app and wakes it.
enum WidgetActionDispatcher {
    enum DispatchError: Error {
        case missing_App_Group
    }

    static func dispatch(_ action: WidgetAction) throws {
        guard let gate = AppGroup.makeConfirmationGate(),
            let inbox = AppGroup.makeActionInbox()
        else { throw DispatchError.missing_App_Group }
        // First tap: the widget reloads and shows "Confirm".
        guard try gate.confirm(action) else { return }
        try inbox.post(action)
        ActionSignal.post()
    }
}

/// Stops or restarts one container. Hidden from Shortcuts: there
/// the two-tap confirmation would be confusing.
struct ContainerActionIntent: AppIntent {
    static var title: LocalizedStringResource { "Stop or Restart" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Container ID") var container_ID: String
    @Parameter(title: "Name") var container_Name: String
    @Parameter(title: "Image") var image: String
    @Parameter(title: "Restart") var restarts: Bool

    init() {}

    init(container: ContainerIdentity, restarts: Bool) {
        container_ID = container.container_ID
        container_Name = container.name
        image = container.image
        self.restarts = restarts
    }

    func perform() async throws -> some IntentResult {
        let identity = ContainerIdentity(
            container_ID: container_ID,
            name: container_Name,
            image: image
        )
        try WidgetActionDispatcher.dispatch(
            restarts
                ? .restart_Container(container: identity)
                : .stop_Container(container: identity)
        )
        return .result()
    }
}

/// Asks one process to quit with SIGTERM.
struct TerminateProcessIntent: AppIntent {
    static var title: LocalizedStringResource { "Quit Process" }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Process ID") var process_ID: Int
    @Parameter(title: "Name") var process_Name: String

    init() {}

    init(process: ProcessIdentity) {
        process_ID = Int(process.pid)
        process_Name = process.name
    }

    func perform() async throws -> some IntentResult {
        let identity = ProcessIdentity(
            pid: Int32(process_ID),
            name: process_Name
        )
        try WidgetActionDispatcher.dispatch(
            .terminate_Process(process: identity)
        )
        return .result()
    }
}

/// Opens the chosen project in the user's editor.
struct OpenProjectIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Project" }
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        try WidgetActionDispatcher.dispatch(.open_Project)
        return .result()
    }
}
