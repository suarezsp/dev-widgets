import DevWidgetsCore
import Foundation

/// Command-line options. GApplication would reject options it
/// does not know, so Swift reads them and GTK only sees argv[0].
public struct LaunchOptions: Equatable, Sendable {
    public enum ColorScheme: Equatable, Sendable {
        case system
        case light
        case dark
    }

    public static let USAGE = """
        Usage: devwidgets [--dark | --light] [--hidden]
                          [--preferences[=alerts|servers|project]]
          --dark, --light   force a colour scheme
          --hidden          start in the tray, without the window
          --preferences     open the preferences at start
        """
    static let PREFERENCES_OPTION = "--preferences"
    static let PREFERENCE_PAGES = [
        "alerts": "Alerts", "servers": "Servers",
        "project": "Project & GitHub",
    ]

    public var color_Scheme = ColorScheme.system
    public var starts_Hidden = false
    /// The page title to open, nil for none.
    public var preferences_Page: String?

    public init() {}

    /// nil for an unknown option or `--help`: print the usage.
    public static func parse(_ arguments: [String]) -> LaunchOptions?
    {
        var options = LaunchOptions()
        for argument in arguments {
            guard options.apply(argument) else { return nil }
        }
        return options
    }

    private mutating func apply(_ argument: String) -> Bool {
        switch argument {
        case "--dark": color_Scheme = .dark
        case "--light": color_Scheme = .light
        case "--hidden": starts_Hidden = true
        case Self.PREFERENCES_OPTION: preferences_Page = "Alerts"
        default: return applyPreferencesPage(argument)
        }
        return true
    }

    private mutating func applyPreferencesPage(
        _ argument: String
    ) -> Bool {
        let prefix = Self.PREFERENCES_OPTION + "="
        guard argument.hasPrefix(prefix),
            let page = Self.PREFERENCE_PAGES[
                String(argument.dropFirst(prefix.count))
            ]
        else { return false }
        preferences_Page = page
        return true
    }
}

/// Where GitHub data comes from on Linux. No keyring: a token in
/// the environment, else the `gh` command, as the transport choice
/// in the core decides. `GH_HOST`, as for `gh`, names a GitHub
/// Enterprise Server host.
public enum GitHubSource {
    public static let TOKEN_VARIABLE = "GITHUB_TOKEN"
    public static let HOST_VARIABLE = "GH_HOST"

    public static func readHost(
        environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) -> GitHubHost {
        GitHubHost(text: environment[HOST_VARIABLE] ?? "")
    }

    public static func readToken(
        environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) -> String? {
        environment[TOKEN_VARIABLE].flatMap { $0.isEmpty ? nil : $0 }
    }

    public static func describe(
        token: String?,
        gh_URL: URL?
    ) -> String {
        if token != nil {
            return "\(TOKEN_VARIABLE) from the environment"
        }
        if let gh_URL { return "gh command (\(gh_URL.path))" }
        return "Not configured: set \(TOKEN_VARIABLE) or install gh"
    }
}

/// The app icon for a run from the build folder: the panel and
/// GTK look in `packaging/linux/icons` of the checkout.
public enum IconLocator {
    static let ICONS_PATH = "packaging/linux/icons"
    static let MAX_LEVELS = 5

    public static func findThemeDirectory(
        executable_URL: URL,
        file_Manager: FileManager = .default
    ) -> URL? {
        var directory_URL = executable_URL.deletingLastPathComponent()
        for _ in 0..<MAX_LEVELS {
            let candidate_URL = directory_URL.appendingPathComponent(
                ICONS_PATH
            )
            if file_Manager.fileExists(atPath: candidate_URL.path) {
                return candidate_URL
            }
            directory_URL.deleteLastPathComponent()
        }
        return nil
    }
}
