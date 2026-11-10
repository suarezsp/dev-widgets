import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// GitHub's REST API over HTTPS. With a token (from the Keychain
/// on macOS) the limit is 5,000 requests an hour; without one,
/// public repositories still answer, 60 times an hour.
public struct RESTTransport: GitHubTransport {
    public static let BASE_URL = "https://api.github.com/"
    public static let API_VERSION = "2022-11-28"
    static let TIMEOUT_SECONDS = 10.0

    let token: String?

    public init(token: String?) {
        self.token = token
    }

    public func fetch(
        _ path: String,
        etag: String?
    ) async throws -> GitHubPage {
        guard let request_URL = URL(string: Self.BASE_URL + path)
        else { throw GitHubError.unreachable(reason: "Bad path") }
        var request = makeRequest(request_URL)
        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        let (body_Data, response) = try await send(request)
        guard let http_Response = response as? HTTPURLResponse else {
            throw GitHubError.unreachable(reason: "No HTTP response")
        }
        let headers = lowercaseHeaders(http_Response)
        try GitHubResponse.check(
            status_Code: http_Response.statusCode,
            headers: headers
        )
        guard http_Response.statusCode != 304 else {
            return .not_Modified
        }
        return .modified(body: body_Data, etag: headers["etag"])
    }

    /// URLSession's own cache is off: it would answer 304s itself
    /// and hide whether GitHub's copy changed.
    func makeRequest(_ request_URL: URL) -> URLRequest {
        var request = URLRequest(
            url: request_URL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.TIMEOUT_SECONDS
        )
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            Self.API_VERSION,
            forHTTPHeaderField: "X-GitHub-Api-Version"
        )
        if let token {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }
        return request
    }

    /// Network failures become `unreachable`, never a crash.
    func send(
        _ request: URLRequest
    ) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw GitHubError.unreachable(
                reason: error.localizedDescription
            )
        }
    }

    func lowercaseHeaders(
        _ response: HTTPURLResponse
    ) -> [String: String] {
        var headers: [String: String] = [:]
        for (name, value) in response.allHeaderFields {
            headers["\(name)".lowercased()] = "\(value)"
        }
        return headers
    }
}
