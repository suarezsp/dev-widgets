import Foundation
import Testing

/// The version lives in `macOS/project.yml`; the Linux packaging
/// files must carry the same one.
struct VersionTests {
    static let ROOT_URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../..")
        .standardizedFileURL
    static let LINUX_FILES = [
        "packaging/linux/changelog.Debian",
        "packaging/linux/"
            + "com.morsetechnologies.DevWidgets.metainfo.xml",
        "packaging/linux/devwidgets.1",
    ]

    static func readFile(_ path: String) throws -> String {
        try String(
            contentsOf: ROOT_URL.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    static func readAppVersion() throws -> String {
        let spec_Text = try readFile("macOS/project.yml")
        let match = try #require(
            spec_Text.firstMatch(
                of: /MARKETING_VERSION: "(\d+\.\d+\.\d+)"/
            )
        )
        return String(match.output.1)
    }

    @Test(arguments: LINUX_FILES)
    func linuxFileCarriesTheAppVersion(path: String) throws {
        let version = try Self.readAppVersion()
        let file_Text = try Self.readFile(path)
        #expect(file_Text.contains(version))
    }

    /// Without these keys XcodeGen writes "1.0" in both Info.plist
    /// files and MARKETING_VERSION never reaches the bundles.
    @Test func bothBundlesTakeTheVersionFromTheSpec() throws {
        let spec_Text = try Self.readFile("macOS/project.yml")
        let version_Keys = spec_Text.components(
            separatedBy:
                "CFBundleShortVersionString: $(MARKETING_VERSION)"
        )
        let build_Keys = spec_Text.components(
            separatedBy: "CFBundleVersion: $(CURRENT_PROJECT_VERSION)"
        )
        #expect(version_Keys.count == 3)
        #expect(build_Keys.count == 3)
    }

    @Test func debianChangelogStartsWithTheAppVersion() throws {
        let version = try Self.readAppVersion()
        let changelog_Text = try Self.readFile(Self.LINUX_FILES[0])
        #expect(changelog_Text.hasPrefix("devwidgets (\(version))"))
    }
}
