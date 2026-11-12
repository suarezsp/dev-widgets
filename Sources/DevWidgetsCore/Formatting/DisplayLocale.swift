import Foundation

/// The locale numbers are written in. It follows the language the
/// texts are shown in, so a Spanish interface writes "1,5 GB" and an
/// English one "1.5 GB"; tests, which run without the catalog, stay
/// English.
public enum DisplayLocale {
    public static let CURRENT = Locale(identifier: readLanguage())

    static func readLanguage() -> String {
        #if canImport(Darwin)
        return Bundle.main.preferredLocalizations.first ?? "en"
        #else
        let is_Translated = !LinuxCatalog.CURRENT.translations.isEmpty
        return is_Translated ? PreferredLanguage.read() ?? "en" : "en"
        #endif
    }

    /// 1.25 with one digit -> "1.3" in English, "1,3" in Spanish.
    public static func formatDecimal(
        _ value: Double,
        digits: Int,
        locale: Locale = CURRENT
    ) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(digits))
                .grouping(.never)
                .locale(locale)
        )
    }
}
