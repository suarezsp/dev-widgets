import Foundation

public enum GitHubError: Error, Equatable {
    case no_Credentials
    case unauthorized
    case rate_Limited(reset_At: Date?)
    /// Also what GitHub answers for a private repository the
    /// credentials cannot see.
    case not_Found
    case unreachable(reason: String)
}

/// One answer to a conditional request.
public enum GitHubPage: Equatable, Sendable {
    case modified(body: Data, etag: String?)
    /// HTTP 304: the body sent with `etag` is still current. Does
    /// not count against GitHub's rate limit.
    case not_Modified
}

/// Fetches one REST path ("repos/o/r/pulls?...") and returns the
/// JSON body, sending `If-None-Match` when an ETag is given. Two
/// implementations: `gh api` and URLSession.
public protocol GitHubTransport: Sendable {
    func fetch(
        _ path: String,
        etag: String?
    ) async throws -> GitHubPage
}

/// Maps HTTP answers to `GitHubError`. Header names lowercased.
public enum GitHubResponse {
    public static func check(
        status_Code: Int,
        headers: [String: String]
    ) throws {
        switch status_Code {
        case 200..<300, 304: return
        case 401: throw GitHubError.unauthorized
        case 403, 429:
            guard
                isRateLimit(
                    status_Code: status_Code,
                    headers: headers
                )
            else { throw GitHubError.unauthorized }
            throw GitHubError.rate_Limited(
                reset_At: readResetDate(headers: headers)
            )
        case 404: throw GitHubError.not_Found
        default:
            throw GitHubError.unreachable(
                reason: "HTTP \(status_Code)"
            )
        }
    }

    /// A 403 without these headers is a permission problem.
    static func isRateLimit(
        status_Code: Int,
        headers: [String: String]
    ) -> Bool {
        status_Code == 429
            || headers["x-ratelimit-remaining"] == "0"
            || headers["retry-after"] != nil
    }

    /// Secondary limits say "retry-after: seconds"; the primary
    /// limit gives the reset as a Unix time.
    static func readResetDate(headers: [String: String]) -> Date? {
        if let retry_Seconds = headers["retry-after"]
            .flatMap(Double.init)
        {
            return Date().addingTimeInterval(retry_Seconds)
        }
        return headers["x-ratelimit-reset"]
            .flatMap(Double.init)
            .map { Date(timeIntervalSince1970: $0) }
    }
}

/// Which transport the app uses (wrapped in a `GitHubClient`). A
/// token the user saved wins: it was set on purpose. Then `gh`,
/// signed in or not (an unsigned `gh` reports `no_Credentials`).
/// nil when there is neither.
public enum GitHubTransportChoice {
    public static func choose(
        token: String?,
        gh_URL: URL? = ExecutableSearch.locate("gh"),
        runner: CommandRunner = ProcessCommandRunner()
    ) -> GitHubTransport? {
        if let token, !token.isEmpty {
            return RESTTransport(token: token)
        }
        return gh_URL.map {
            GhCommandTransport(runner: runner, gh_URL: $0)
        }
    }
}
