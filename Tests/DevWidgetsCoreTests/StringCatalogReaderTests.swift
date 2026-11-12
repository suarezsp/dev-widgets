import Foundation
import Testing

@testable import DevWidgetsCore

struct StringCatalogReaderTests {
    static let CATALOG_JSON = """
        {"sourceLanguage": "en", "strings": {
          "Clean": {"localizations": {"es": {"stringUnit":
            {"state": "translated", "value": "Limpio"}}}},
          "%@ of %@": {"localizations": {"es": {"stringUnit":
            {"state": "translated", "value": "%1$@ de %2$@"}}}},
          "CPU": {"shouldTranslate": false}
        }}
        """

    static func makeCatalog() throws -> StringCatalog {
        try #require(
            StringCatalog(
                json_Data: Data(CATALOG_JSON.utf8),
                language: "es"
            )
        )
    }

    @Test func spanishTextsAreRead() throws {
        let catalog = try Self.makeCatalog()
        #expect(catalog.translate("Clean") == "Limpio")
        #expect(
            catalog.translate("%@ of %@", arguments: ["2", "8"])
                == "2 de 8"
        )
        #expect(catalog.translate("CPU") == "CPU")
    }

    @Test func missingTextStaysEnglish() throws {
        let catalog = try Self.makeCatalog()
        #expect(
            catalog.translate("%lld cores", arguments: ["8"])
                == "8 cores"
        )
        #expect(
            StringCatalog(json_Data: Data(), language: "es") == nil
        )
    }

    @Test func placeholdersTakeTheirArguments() {
        #expect(
            StringCatalog.fill("%2$@ · %1$@", with: ["a", "b"])
                == "b · a"
        )
        #expect(
            StringCatalog.fill("%lld%% of %@", with: ["5", "x"])
                == "5% of x"
        )
        #expect(
            StringCatalog.fill("%@ and %@", with: ["a"]) == "a and "
        )
    }

    @Test(
        arguments: [
            (["LANG": "es_ES.UTF-8"], "es"),
            (["LANGUAGE": "es:en", "LANG": "en_US.UTF-8"], "es"),
            (["LANGUAGE": "", "LC_ALL": "fr_FR"], "fr"),
            (["LANG": "C.UTF-8"], nil),
            ([:], nil),
        ] as [([String: String], String?)]
    )
    func languageComesFromTheLocale(
        environment: [String: String],
        language: String?
    ) {
        #expect(
            PreferredLanguage.read(environment: environment)
                == language
        )
    }
}
