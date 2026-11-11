import AppKit

/// Quits a regular app the way the Dock does, with a quit Apple
/// event, so it can ask to save; background processes are left to
/// SIGTERM. `NSRunningApplication` is documented as thread safe.
enum AppQuitter {
    static func quit(_ process_ID: Int32) -> Bool {
        guard
            let app = NSRunningApplication(
                processIdentifier: process_ID
            ),
            app.activationPolicy == .regular
        else { return false }
        return app.terminate()
    }
}
