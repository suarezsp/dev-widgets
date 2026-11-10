import Foundation
import ServiceManagement

/// Starts the app at login, so the widgets get fresh data after a
/// restart without the user opening the app. It is on after the
/// first launch; Settings › General and System Settings › General ›
/// Login Items turn it off.
enum LoginItem {
    static var is_Enabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needs_Approval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func registerOnFirstLaunch() {
        let offer = LoginItemOffer(defaults: .standard)
        guard offer.takeFirstLaunch() else { return }
        try? SMAppService.mainApp.register()
    }

    /// Throws what ServiceManagement reports, for Settings to show.
    static func setEnabled(_ is_On: Bool) throws {
        if is_On {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
