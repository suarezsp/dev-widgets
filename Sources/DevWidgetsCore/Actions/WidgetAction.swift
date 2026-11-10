import Foundation

/// What a widget button or the menu bar panel can ask for.
public enum WidgetAction: Codable, Hashable, Sendable {
    case stop_Container(container: ContainerIdentity)
    /// `docker restart`: stop as above, then start again.
    case restart_Container(container: ContainerIdentity)
    /// The name guards against the pid being reused meanwhile.
    case terminate_Process(process: ProcessIdentity)
    case open_Project

    /// Stopping, restarting and terminating lose work (state held
    /// in memory, open connections): they need a second tap.
    public var needs_Confirmation: Bool { self != .open_Project }

    /// "Stop api-db-1", "Quit node", "Open project".
    public var title: String {
        switch self {
        case .stop_Container(let container):
            "Stop \(container.name)"
        case .restart_Container(let container):
            "Restart \(container.name)"
        case .terminate_Process(let process): "Quit \(process.name)"
        case .open_Project: "Open project"
        }
    }
}

public enum ActionOutcome: Equatable, Sendable {
    case done
    /// Not attempted: unsafe, or the target is already gone.
    case refused(reason: String)
    case failed(reason: String)

    /// What the user is told when it did not work; nil on success.
    public func describeFailure(
        of action: WidgetAction
    ) -> AlertMessage? {
        switch self {
        case .done: nil
        case .refused(let reason), .failed(let reason):
            AlertMessage(
                title: "\(action.title) failed",
                body: reason
            )
        }
    }
}
