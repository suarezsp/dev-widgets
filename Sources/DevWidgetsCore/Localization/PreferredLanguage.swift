import Foundation

/// The user's language from the POSIX locale variables, in the
/// order gettext reads them: "es_ES.UTF-8" -> "es".
public enum PreferredLanguage {
    public static let VARIABLES = [
        "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG",
    ]
    /// Locales that mean "no translation".
    static let UNTRANSLATED = ["", "C", "POSIX"]

    public static func read(
        environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) -> String? {
        let locale_Text = VARIABLES.lazy
            .compactMap { environment[$0] }
            .first { !$0.isEmpty }
        let first_Locale =
            locale_Text?
            .split(separator: ":").first.map(String.init) ?? ""
        let language = first_Locale.prefix {
            $0 != "_" && $0 != "." && $0 != "@"
        }
        guard !UNTRANSLATED.contains(String(language)) else {
            return nil
        }
        return language.lowercased()
    }
}
