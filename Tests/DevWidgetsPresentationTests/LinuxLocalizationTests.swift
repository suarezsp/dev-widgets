#if !canImport(Darwin)
import Foundation
import Testing

@testable import DevWidgetsPresentation

/// The Linux stand-in for `String(localized:)` builds the same
/// keys Xcode writes, so both platforms share one catalog.
struct LinuxLocalizationTests {
    @Test func interpolationsBecomePlaceholders() {
        let alias = "web"
        let value: LinuxLocalizationValue =
            "Monitor \(alias) every \(5) s"
        #expect(value.key == "Monitor %@ every %lld s")
        #expect(value.arguments == ["web", "5"])
    }

    @Test func plainTextIsItsOwnKey() {
        let value: LinuxLocalizationValue = "Above (%)"
        #expect(value.key == "Above (%)")
        #expect(value.arguments.isEmpty)
    }

    @Test func checkoutCatalogIsFound() throws {
        let catalog_URL = try #require(LinuxCatalog.locate())
        #expect(
            catalog_URL.lastPathComponent == "Localizable.xcstrings"
        )
    }
}
#endif
