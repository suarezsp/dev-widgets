import Foundation

/// Remembers that start at login was already turned on once, so the
/// app registers itself on the first launch only and a user who
/// turns it off later keeps it off.
struct LoginItemOffer {
    static let KEY = "loginItemOffered"

    let defaults: UserDefaults

    /// True the first time it is asked, false ever after.
    func takeFirstLaunch() -> Bool {
        guard !defaults.bool(forKey: Self.KEY) else { return false }
        defaults.set(true, forKey: Self.KEY)
        return true
    }
}
