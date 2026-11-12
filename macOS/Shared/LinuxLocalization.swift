import Foundation

#if !canImport(Darwin)
extension String {
    /// Linux has no String Catalog, so the English text is the
    /// text. On macOS, Foundation's `String(localized:)` looks it
    /// up in `Localizable.xcstrings`.
    init(localized text: String) {
        self = text
    }
}
#endif
