import Foundation

/// GitHub through the `gh` command, which keeps its own token (in
/// the macOS Keychain) after `gh auth login`. `-i` prints the
/// status line and headers before the body, for the ETag.
public struct GhCommandTransport: GitHubTransport {
    public let runner: CommandRunner
    public let gh_URL: URL
    public var host = GitHubHost.PUBLIC

    public init(runner: CommandRunner, gh_URL: URL) {
        self.runner = runner
        self.gh_URL = gh_URL
    }

    public func fetch(
        _ path: String,
        etag: String?
    ) async throws -> GitHubPage {
        let command = makeCommand(path: path, etag: etag)
        do {
            let output = try await runner.runInBackground(command)
            return GhIncludeParser.parsePage(output)
        } catch CommandError.failed(_, let error_Text) {
            if error_Text.contains("HTTP 304") {
                return .not_Modified
            }
            throw Self.classify(error_Text: error_Text)
        } catch {
            throw GitHubError.unreachable(
                reason: "gh did not answer"
            )
        }
    }

    func makeCommand(path: String, etag: String?) -> Command {
        Command(
            executable_URL: gh_URL,
            arguments: Self.makeArguments(
                path: path,
                etag: etag,
                host: host
            )
        )
    }

    /// `--hostname` only for Enterprise: for github.com, `gh`
    /// keeps honouring `GH_HOST` as it always did.
    static func makeArguments(
        path: String,
        etag: String?,
        host: GitHubHost = .PUBLIC
    ) -> [String] {
        let header_Arguments = etag.map {
            ["-H", "If-None-Match: \($0)"]
        }
        let host_Arguments =
            host.is_Public ? [] : ["--hostname", host.name]
        return ["api", "-i"] + host_Arguments
            + (header_Arguments ?? []) + [path]
    }

    /// `gh` reports HTTP failures as "gh: Not Found (HTTP 404)".
    static func classify(error_Text: String) -> GitHubError {
        if error_Text.contains("gh auth login") {
            return .no_Credentials
        }
        if error_Text.contains("HTTP 429")
            || error_Text.lowercased().contains("rate limit")
        {
            return .rate_Limited(reset_At: nil)
        }
        if error_Text.contains("HTTP 401")
            || error_Text.contains("HTTP 403")
        {
            return .unauthorized
        }
        if error_Text.contains("HTTP 404") { return .not_Found }
        let first_Line = error_Text.split(separator: "\n").first
        return .unreachable(reason: first_Line.map(String.init) ?? "")
    }
}

/// Splits `gh api -i` output: "HTTP/2.0 200 OK", "Name: value"
/// lines ending in CRLF, an empty line, then the body.
enum GhIncludeParser {
    static func parsePage(_ output: String) -> GitHubPage {
        guard output.hasPrefix("HTTP/") else {
            return .modified(body: Data(output.utf8), etag: nil)
        }
        let separator_Range =
            output.range(of: "\r\n\r\n")
            ?? output.range(of: "\n\n")
        guard let separator_Range else {
            return .modified(body: Data(), etag: nil)
        }
        let head_Text = output[..<separator_Range.lowerBound]
        let body_Text = output[separator_Range.upperBound...]
        return .modified(
            body: Data(body_Text.utf8),
            etag: findETag(in: head_Text)
        )
    }

    /// Go prints header names canonically ("Etag").
    static func findETag(in head_Text: Substring) -> String? {
        let etag_Line = head_Text.split(whereSeparator: \.isNewline)
            .first { $0.lowercased().hasPrefix("etag:") }
        return etag_Line.map {
            $0.dropFirst("etag:".count)
                .trimmingCharacters(in: .whitespaces)
        }
    }
}
