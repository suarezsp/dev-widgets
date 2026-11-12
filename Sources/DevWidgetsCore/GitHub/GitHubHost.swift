import Foundation

/// github.com or a GitHub Enterprise Server host, whose REST API
/// lives under `/api/v3`.
public struct GitHubHost: Equatable, Sendable {
    public static let PUBLIC_NAME = "github.com"
    public static let PUBLIC_API_BASE = "https://api.github.com/"
    public static let PUBLIC = GitHubHost(text: "")
    /// Where the macOS app keeps the host the user typed.
    public static let SETTING_KEY = "GitHubHost"

    public let name: String

    /// "https://GHE.example.com/" -> "ghe.example.com"; an empty
    /// text means github.com.
    public init(text: String) {
        var host_Text = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        for scheme in ["https://", "http://"]
        where host_Text.hasPrefix(scheme) {
            host_Text.removeFirst(scheme.count)
        }
        let name = host_Text.split(separator: "/").first
        self.name = name.map(String.init) ?? Self.PUBLIC_NAME
    }

    public var is_Public: Bool { name == Self.PUBLIC_NAME }

    public var api_Base: String {
        is_Public ? Self.PUBLIC_API_BASE : "https://\(name)/api/v3/"
    }
}
