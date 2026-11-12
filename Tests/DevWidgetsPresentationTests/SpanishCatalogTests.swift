import Foundation
import Testing

/// Every text the catalog marks as translatable has a Spanish value
/// with the same placeholders, so no format argument goes missing.
struct SpanishCatalogTests {
    static func readSpanishValue(_ entry: Any) -> String? {
        let entry_Fields = entry as? [String: Any]
        let localizations = entry_Fields?["localizations"]
        let spanish = (localizations as? [String: Any])?["es"]
        let unit = (spanish as? [String: Any])?["stringUnit"]
        return (unit as? [String: Any])?["value"] as? String
    }

    static func isTranslatable(_ entry: Any) -> Bool {
        let entry_Fields = entry as? [String: Any]
        return entry_Fields?["shouldTranslate"] as? Bool != false
    }

    /// Placeholder kinds in order of argument, without positions.
    static func listPlaceholders(_ text: String) -> [String] {
        let matches = text.matches(of: /%(?:\d+\$)?(@|lld)/)
        return matches.map { String($0.output.1) }
    }

    static func readStrings() throws -> [String: Any] {
        try #require(
            StringCatalogTests.readCatalog()["strings"]
                as? [String: Any]
        )
    }

    @Test func everyTextHasSpanish() throws {
        let strings = try Self.readStrings()
        let missing_Keys =
            strings
            .filter { Self.isTranslatable($0.value) }
            .filter { Self.readSpanishValue($0.value) == nil }
            .map(\.key)
        #expect(missing_Keys.isEmpty, "\(missing_Keys.sorted())")
    }

    @Test func spanishKeepsThePlaceholders() throws {
        for (key, entry) in try Self.readStrings() {
            guard let spanish = Self.readSpanishValue(entry) else {
                continue
            }
            let source_Kinds = Self.listPlaceholders(key)
            let spanish_Kinds = Self.listPlaceholders(spanish)
            #expect(source_Kinds == spanish_Kinds, "\(key)")
        }
    }
}
