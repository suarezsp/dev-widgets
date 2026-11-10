import DevWidgetsCore
import Foundation

/// Entries for a widget that may show an armed "Confirm" button:
/// one now and, while armed, one when the window closes, so the
/// button turns back without waiting for the next reload.
enum ArmedActionTimeline {
    static func makeDates() -> [(date: Date, armed: WidgetAction?)] {
        let now = Date()
        guard
            let armed_Action = AppGroup.makeConfirmationGate()?
                .readArmedAction(at: now)
        else { return [(now, nil)] }
        let expiry_Date = now.addingTimeInterval(
            ConfirmationGate.WINDOW_SECONDS
        )
        return [(now, armed_Action), (expiry_Date, nil)]
    }
}
