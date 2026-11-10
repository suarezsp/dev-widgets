import DevWidgetsCore
import Foundation
import Testing

@testable import DevWidgetsLinuxShell

struct LinuxSettingsTests {
    static func makeStore() -> LinuxSettingsStore {
        LinuxSettingsStore(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("dw-\(UUID().uuidString)")
        )
    }

    @Test func missingFileGivesDefaults() {
        #expect(Self.makeStore().load() == LinuxSettings())
    }

    @Test func settingsSurviveSaveAndLoad() throws {
        let store = Self.makeStore()
        var settings = LinuxSettings()
        settings.project_Path = "/home/me/api"
        settings.hosts = [try #require(RemoteHost(alias: "web-1"))]
        settings.alert_Settings.notifies_Server_Down = false
        try store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func damagedHostIsDroppedAlone() throws {
        let json_Text = """
            {"hosts": [{"alias": "web-1"}, {"alias": "-oProxy=x"}],
             "project_Path": "/srv/app"}
            """
        let settings = try JSONDecoder().decode(
            LinuxSettings.self,
            from: Data(json_Text.utf8)
        )
        #expect(settings.hosts.map(\.alias) == ["web-1"])
        #expect(settings.project_URL?.path == "/srv/app")
        #expect(settings.alert_Settings == .DEFAULT)
    }

    @Test func configFolderFollowsXDG() {
        let directory = LinuxSettingsStore.findDirectory(
            environment: ["XDG_CONFIG_HOME": "/tmp/cfg"]
        )
        #expect(directory.path == "/tmp/cfg/devwidgets")
        let fallback = LinuxSettingsStore.findDirectory(
            environment: ["XDG_CONFIG_HOME": ""]
        )
        #expect(fallback.path.hasSuffix("/.config/devwidgets"))
    }
}

struct AlertRouterTests {
    static func makeCIAlert() throws -> CIFailureAlert {
        let page_URL = try #require(URL(string: "https://x.test/run"))
        var run = WorkflowRunSummary(
            run_ID: 1,
            workflow_Name: "Tests",
            outcome: .failure
        )
        run.page_URL = page_URL
        let status = GitHubStatus(
            repository: GitHubRepository(owner: "acme", name: "api"),
            branch_Name: "main",
            runs: [run]
        )
        return CIFailureAlert(status: status)
    }

    @Test func ciAlertKeepsItsPageAndHonoursTheSwitch() throws {
        let router = AlertRouter()
        var settings = AlertSettings.DEFAULT
        let alert = try Self.makeCIAlert()
        let shown = router.route(alert, settings: settings)
        #expect(shown.first?.identifier == "ci.acme/api#main")
        #expect(
            shown.first?.page_URL?.absoluteString
                == "https://x.test/run"
        )
        settings.notifies_CI_Failure = false
        #expect(router.route(alert, settings: settings).isEmpty)
    }

    @Test func serverDownWaitsAMinute() throws {
        var router = AlertRouter()
        let host = try #require(RemoteHost(alias: "db-1"))
        let start = Date(timeIntervalSince1970: 0)
        let counts = (0..<5).map { index in
            var overview = ServerOverview(reports: [
                RemoteHostReport(
                    host: host,
                    state: .failed(
                        problem: .unreachable(reason: "Timed out")
                    )
                )
            ])
            overview.captured_At = start.addingTimeInterval(
                Double(index) * 15
            )
            return router.route(overview, settings: .DEFAULT).count
        }
        #expect(counts == [0, 0, 0, 0, 1])
    }
}

struct TrayStateTests {
    @Test func startingStateAsksForNothing() {
        #expect(TrayState.STARTING.status_Text == "Active")
    }

    @Test func attentionMapsToTheSpecStatus() {
        let state = TrayState(tooltip_Text: "", needs_Attention: true)
        #expect(state.status_Text == "NeedsAttention")
    }

    @Test func busNameFollowsTheSpec() {
        #expect(
            StatusNotifierProtocol.makeBusName(process_ID: 42)
                == "org.kde.StatusNotifierItem-42-1"
        )
    }

    @Test func introspectionDeclaresWhatHostsCall() {
        let xml_Text = StatusNotifierProtocol.INTROSPECTION_XML
        for member in ["Activate", "ToolTip", "IconName", "Status"] {
            #expect(xml_Text.contains("name=\"\(member)\""))
        }
    }

    @Test func sizesMatchTheMacFamilies() {
        #expect(WidgetSize.small.width == WidgetSize.small.height)
        #expect(WidgetSize.medium.width == 2 * 170 + 24)
        #expect(
            WidgetSize.extra_Large.height == WidgetSize.large.height
        )
    }

    @Test func everyDeclaredPropertyHasAValue() {
        let properties = TrayProperties(icon_Theme_Path: "/icons")
        let xml_Text = StatusNotifierProtocol.INTROSPECTION_XML
        let names = xml_Text.components(
            separatedBy: "<property name=\""
        )
        .dropFirst()
        .compactMap { $0.split(separator: "\"").first }
        #expect(names.count == 8)
        for name in names {
            #expect(
                properties.value(
                    named: String(name),
                    state: .STARTING
                )
                    != nil
            )
        }
    }

    @Test func tooltipCarriesTheSummary() {
        let state = TrayState(
            tooltip_Text: "CPU 12%",
            needs_Attention: true
        )
        let properties = TrayProperties()
        #expect(
            properties.value(named: "ToolTip", state: state)
                == .tooltip(title: "DevWidgets", body: "CPU 12%")
        )
        #expect(
            properties.value(named: "Status", state: state)
                == .text("NeedsAttention")
        )
        #expect(properties.value(named: "Menu", state: state) == nil)
    }
}

struct LaunchOptionsTests {
    @Test func noArgumentsMeansDefaults() {
        #expect(LaunchOptions.parse([]) == LaunchOptions())
    }

    @Test func readsEveryOption() throws {
        let options = try #require(
            LaunchOptions.parse([
                "--dark", "--hidden", "--preferences=servers",
            ])
        )
        #expect(options.color_Scheme == .dark)
        #expect(options.starts_Hidden)
        #expect(options.preferences_Page == "Servers")
    }

    @Test(arguments: ["--help", "--preferences=nope", "-x", "dark"])
    func refusesUnknownOptions(_ argument: String) {
        #expect(LaunchOptions.parse([argument]) == nil)
    }
}

struct GitHubSourceTests {
    @Test func emptyTokenCountsAsNone() {
        #expect(GitHubSource.readToken(environment: [:]) == nil)
        #expect(
            GitHubSource.readToken(environment: ["GITHUB_TOKEN": ""])
                == nil
        )
        #expect(
            GitHubSource.readToken(environment: ["GITHUB_TOKEN": "t"])
                == "t"
        )
    }

    @Test func tokenWinsOverGh() {
        let gh_URL = URL(fileURLWithPath: "/usr/bin/gh")
        #expect(
            GitHubSource.describe(token: "t", gh_URL: gh_URL)
                .hasPrefix("GITHUB_TOKEN")
        )
        #expect(
            GitHubSource.describe(token: nil, gh_URL: gh_URL)
                == "gh command (/usr/bin/gh)"
        )
        #expect(
            GitHubSource.describe(token: nil, gh_URL: nil)
                .hasPrefix("Not configured")
        )
    }
}

struct IconLocatorTests {
    @Test func findsTheCheckoutIcons() throws {
        let root_URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root_URL) }
        let icons_URL = root_URL.appendingPathComponent(
            "packaging/linux/icons"
        )
        try FileManager.default.createDirectory(
            at: icons_URL,
            withIntermediateDirectories: true
        )
        let found_URL = IconLocator.findThemeDirectory(
            executable_URL: root_URL.appendingPathComponent(
                ".build/debug/devwidgets-linux"
            )
        )
        #expect(
            found_URL?.standardizedFileURL.path
                == icons_URL.standardizedFileURL.path
        )
    }

    @Test func installedCopiesUseTheTheme() {
        #expect(
            IconLocator.findThemeDirectory(
                executable_URL: URL(fileURLWithPath: "/usr/bin/x")
            ) == nil
        )
    }
}
