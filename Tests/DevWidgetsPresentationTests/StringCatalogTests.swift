import Foundation
import Testing

/// Every plain `String(localized: "…")` text in `macOS/` is in the
/// String Catalog; `tools/sync_strings.sh` adds new ones.
struct StringCatalogTests {
    static let MACOS_URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../macOS")
        .standardizedFileURL
    static let CATALOG_PATH = "Shared/Localizable.xcstrings"

    static func readCatalog() throws -> [String: Any] {
        let catalog_Data = try Data(
            contentsOf: MACOS_URL.appendingPathComponent(CATALOG_PATH)
        )
        return try #require(
            JSONSerialization.jsonObject(with: catalog_Data)
                as? [String: Any]
        )
    }

    /// Single-line texts without interpolation, which keep their
    /// source spelling as the catalog key.
    static func listPlainTexts() throws -> Set<String> {
        let source_Folders = ["App", "Shared", "Widgets"]
        var texts = Set<String>()
        for folder in source_Folders {
            for file_Text in try readSwiftFiles(in: folder) {
                let matches = file_Text.matches(
                    of: /String\(localized: "([^"\\]+)"\)/
                )
                texts.formUnion(matches.map { String($0.output.1) })
            }
        }
        return texts
    }

    static func readSwiftFiles(in folder: String) throws -> [String] {
        let folder_URL = MACOS_URL.appendingPathComponent(folder)
        let enumerator = FileManager.default.enumerator(
            at: folder_URL,
            includingPropertiesForKeys: nil
        )
        let file_URLs = (enumerator?.allObjects ?? [])
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        return try file_URLs.map {
            try String(contentsOf: $0, encoding: .utf8)
        }
    }

    @Test func catalogHasEveryPlainText() throws {
        let plain_Texts = try Self.listPlainTexts()
        let strings = try #require(
            Self.readCatalog()["strings"] as? [String: Any]
        )
        let missing_Texts = plain_Texts.subtracting(strings.keys)
        #expect(!plain_Texts.isEmpty)
        #expect(missing_Texts.isEmpty, "\(missing_Texts.sorted())")
    }

    @Test func catalogIsInEnglish() throws {
        let source_Language = try Self.readCatalog()["sourceLanguage"]
        #expect(source_Language as? String == "en")
    }
}
