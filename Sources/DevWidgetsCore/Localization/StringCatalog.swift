import Foundation

/// Reads `Localizable.xcstrings` where Foundation cannot (Linux):
/// the translations of one language, and the `%@`, `%lld` and
/// `%1$@` placeholders Xcode writes for interpolated values.
public struct StringCatalog: Sendable {
    public static let FILE_NAME = "Localizable.xcstrings"
    public static let EMPTY = StringCatalog(translations: [:])

    /// Catalog key (the English text) to translated text.
    public let translations: [String: String]

    public init(translations: [String: String]) {
        self.translations = translations
    }

    /// nil when the file is not a catalog.
    public init?(json_Data: Data, language: String) {
        guard
            let catalog = try? JSONDecoder().decode(
                CatalogPayload.self,
                from: json_Data
            )
        else { return nil }
        translations = catalog.strings.compactMapValues {
            $0.localizations?[language]?.string_Unit?.value
        }
    }

    /// The translation of `key` with `arguments` in place of its
    /// placeholders, or the key itself (English) filled the same
    /// way.
    public func translate(
        _ key: String,
        arguments: [String] = []
    ) -> String {
        Self.fill(translations[key] ?? key, with: arguments)
    }

    /// "%2$@ de %1$@" with ["a", "b"] -> "b de a"; unnumbered
    /// placeholders take the arguments in order; "%%" is "%".
    public static func fill(
        _ template: String,
        with arguments: [String]
    ) -> String {
        var next_Index = 0
        return template.replacing(/%(?:(\d+)\$)?(@|lld|%)/) { match in
            guard match.output.2 != "%" else { return "%" }
            let index =
                match.output.1.flatMap { Int($0) }.map { $0 - 1 }
                ?? next_Index
            next_Index += 1
            let in_Range = arguments.indices.contains(index)
            return in_Range ? arguments[index] : ""
        }
    }
}

struct CatalogPayload: Decodable {
    let strings: [String: EntryPayload]
}

struct EntryPayload: Decodable {
    let localizations: [String: LocalizationPayload]?
}

struct LocalizationPayload: Decodable {
    let string_Unit: StringUnitPayload?

    enum CodingKeys: String, CodingKey {
        case string_Unit = "stringUnit"
    }
}

struct StringUnitPayload: Decodable {
    let value: String
}
