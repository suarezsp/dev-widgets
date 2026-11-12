import DevWidgetsCore
import Foundation

/// How an action looks on a button, in widgets and in the panel.
extension WidgetAction {
    public var symbol_Name: String {
        switch self {
        case .stop_Container: "stop.circle"
        case .restart_Container: "arrow.clockwise.circle"
        case .terminate_Process: "xmark.circle"
        case .open_Project: "arrow.up.forward.app"
        }
    }

    /// What the confirmation dialog explains.
    public var consequence_Text: String {
        switch self {
        case .stop_Container:
            String(
                localized: """
                    Docker asks it to stop and forces it after 10 \
                    seconds.
                    """
            )
        case .restart_Container:
            String(
                localized: """
                    Docker stops it, forcing it after 10 seconds, \
                    then starts it again.
                    """
            )
        case .terminate_Process(let process):
            describeQuit(pid_Text: String(process.pid))
        case .open_Project:
            String(localized: "Opens the project in your editor.")
        }
    }

    func describeQuit(pid_Text: String) -> String {
        String(
            localized: """
                Process \(pid_Text) is asked to quit and can save \
                its work first.
                """
        )
    }
}
