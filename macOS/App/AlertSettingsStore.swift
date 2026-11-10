import DevWidgetsCore
import Foundation

/// Alert settings as JSON in user defaults; defaults when absent or
/// unreadable (e.g. written by a future version).
enum AlertSettingsStore {
    static let KEY = "alertSettings"

    static func load() -> AlertSettings {
        guard
            let settings_Data = UserDefaults.standard.data(
                forKey: KEY
            ),
            let settings = try? JSONDecoder().decode(
                AlertSettings.self,
                from: settings_Data
            )
        else { return .DEFAULT }
        return settings
    }

    static func save(_ settings: AlertSettings) {
        let settings_Data = try? JSONEncoder().encode(settings)
        UserDefaults.standard.set(settings_Data, forKey: KEY)
    }
}
