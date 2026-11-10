import Foundation
import Testing
@testable import DevWidgetsPresentation

/// Start at login is turned on by the first launch only.
struct LoginItemOfferTests {
    static func makeDefaults() throws -> UserDefaults {
        let suite_Name = "LoginItemOfferTests." + UUID().uuidString
        return try #require(UserDefaults(suiteName: suite_Name))
    }

    @Test func onlyTheFirstLaunchRegisters() throws {
        let offer = LoginItemOffer(defaults: try Self.makeDefaults())
        #expect(offer.takeFirstLaunch())
        #expect(!offer.takeFirstLaunch())
        #expect(!offer.takeFirstLaunch())
    }

    @Test func theChoiceSurvivesARelaunch() throws {
        let defaults = try Self.makeDefaults()
        _ = LoginItemOffer(defaults: defaults).takeFirstLaunch()
        let relaunched = LoginItemOffer(defaults: defaults)
        #expect(defaults.bool(forKey: LoginItemOffer.KEY))
        #expect(!relaunched.takeFirstLaunch())
    }
}
