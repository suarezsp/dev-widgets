import Foundation

/// Finds the GitHub repository in a Git remote URL, in the three
/// forms Git accepts: scp-like SSH, `ssh://` and HTTPS.
public enum GitRemoteParser {
    public static func parseRepository(
        remote_URL: String,
        host: GitHubHost = .PUBLIC
    ) -> GitHubRepository? {
        guard let path = extractPath(remote_URL, host: host) else {
            return nil
        }
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        let name =
            parts[1].hasSuffix(".git")
            ? String(parts[1].dropLast(4)) : parts[1]
        guard !parts[0].isEmpty, !name.isEmpty else { return nil }
        return GitHubRepository(owner: parts[0], name: name)
    }

    /// "owner/name(.git)" when the remote is on `host`.
    static func extractPath(
        _ remote_URL: String,
        host: GitHubHost
    ) -> String? {
        let trimmed_URL = remote_URL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let scp_Prefix = "git@\(host.name):"
        if trimmed_URL.hasPrefix(scp_Prefix) {
            return String(trimmed_URL.dropFirst(scp_Prefix.count))
        }
        guard let components = URLComponents(string: trimmed_URL),
            components.host?.lowercased() == host.name
        else { return nil }
        return String(components.path.drop { $0 == "/" })
    }
}
