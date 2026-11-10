import Foundation
import Testing

/// The XcodeGen spec gives both targets the same team-prefixed App
/// Group, as entitlement and as the Info.plist key `AppGroup` reads,
/// and the hardened runtime notarization requires.
struct ProjectSpecTests {
    static let SPEC_URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../macOS/project.yml")
        .standardizedFileURL

    @Test func bothTargetsShareTheTeamPrefixedAppGroup() throws {
        let spec_Text = try String(
            contentsOf: Self.SPEC_URL,
            encoding: .utf8
        )
        #expect(
            spec_Text.contains(
                "$(TeamIdentifierPrefix)com.morsetechnologies"
            )
        )
        let info_Lines = spec_Text.components(
            separatedBy: "DevWidgetsAppGroup: $(APP_GROUP_IDENTIFIER)"
        )
        let entitlement_Lines = spec_Text.components(
            separatedBy: "- $(APP_GROUP_IDENTIFIER)"
        )
        #expect(info_Lines.count == 3)
        #expect(entitlement_Lines.count == 3)
        #expect(!spec_Text.contains("group.com."))
    }

    @Test func bothTargetsUseTheHardenedRuntime() throws {
        let spec_Text = try String(
            contentsOf: Self.SPEC_URL,
            encoding: .utf8
        )
        let shared_Text = spec_Text.components(
            separatedBy: "targets:"
        )[0]
        let runtime_Lines = spec_Text.components(
            separatedBy: "ENABLE_HARDENED_RUNTIME: YES"
        )
        #expect(shared_Text.contains("ENABLE_HARDENED_RUNTIME: YES"))
        #expect(runtime_Lines.count == 2)
    }
}
