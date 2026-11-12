import Foundation

/// A transport plus an ETag cache. GitHub answers an unchanged
/// page with 304 and does not count it against the rate limit,
/// so a refresh of a quiet branch costs nothing. Keep one client
/// for the app's life: the cache is the point.
public actor GitHubClient {
    public static let MAX_CACHED_PAGES = 64

    struct CachedPage {
        let etag: String
        let body: Data
    }

    let transport: GitHubTransport
    private var cached_Pages: [String: CachedPage] = [:]
    /// Oldest first, for eviction.
    private var cached_Paths: [String] = []
    public private(set) var request_Count = 0
    public private(set) var not_Modified_Count = 0

    public init(transport: GitHubTransport) {
        self.transport = transport
    }

    public nonisolated var host: GitHubHost { transport.host }

    public func fetch(_ path: String) async throws -> Data {
        let cached_Page = cached_Pages[path]
        let page = try await transport.fetch(
            path,
            etag: cached_Page?.etag
        )
        request_Count += 1
        switch page {
        case .modified(let body, let etag):
            remember(path: path, etag: etag, body: body)
            return body
        case .not_Modified:
            not_Modified_Count += 1
            guard let cached_Page else {
                throw GitHubError.unreachable(
                    reason: "Not modified, but nothing cached"
                )
            }
            return cached_Page.body
        }
    }

    private func remember(path: String, etag: String?, body: Data) {
        cached_Paths.removeAll { $0 == path }
        guard let etag else {
            cached_Pages[path] = nil
            return
        }
        cached_Pages[path] = CachedPage(etag: etag, body: body)
        cached_Paths.append(path)
        if cached_Paths.count > Self.MAX_CACHED_PAGES {
            cached_Pages[cached_Paths.removeFirst()] = nil
        }
    }
}
