import Foundation

/// One open pull request that asks the user for a review.
public struct ReviewRequest: Codable, Hashable, Sendable {
    public let repository: GitHubRepository
    public let number: Int
    public let title: String
    public var author_Login = ""
    public var page_URL: URL?

    public init(
        repository: GitHubRepository,
        number: Int,
        title: String
    ) {
        self.repository = repository
        self.number = number
        self.title = title
    }
}

/// Pull requests awaiting the user's review, in every repository,
/// most recently updated first.
public struct ReviewQueue: Codable, Equatable, Sendable {
    /// All matches; `requests` holds only the first page.
    public let total_Count: Int
    public let requests: [ReviewRequest]

    public init(total_Count: Int, requests: [ReviewRequest]) {
        self.total_Count = total_Count
        self.requests = requests
    }
}

public enum ReviewQueueState: Codable, Equatable, Sendable {
    case not_Loaded
    /// Same problems as the branch status: no credentials, rate
    /// limit, unreachable.
    case failed(problem: GitHubState)
    case available(queue: ReviewQueue)

    /// What `GitHubSchedule` needs to know: only a rate limit
    /// changes when to ask next.
    public var schedule_State: GitHubState {
        guard case .failed(let problem) = self else {
            return .not_Configured
        }
        return problem
    }
}

/// Reads the queue with GitHub's issue search. Search answers carry
/// no ETag (checked on 2026-11-10), so the queue is asked rarely.
public struct ReviewQueueReader: Sendable {
    public static let INTERVAL_SECONDS = 300.0
    public static let PAGE_SIZE = 10
    /// `@me` needs credentials; anonymous search answers 422.
    static let QUERY =
        "is:pr is:open archived:false review-requested:@me"

    public let client: GitHubClient?

    public init(client: GitHubClient?) {
        self.client = client
    }

    public func readState() async -> ReviewQueueState {
        guard let client else {
            return .failed(problem: .no_Credentials)
        }
        do {
            let json_Data = try await client.fetch(
                Self.makePath(query: Self.QUERY)
            )
            return .available(
                queue: try ReviewQueueParser.parseQueue(json_Data)
            )
        } catch {
            return .failed(problem: GitHubReader.describe(error))
        }
    }

    static func makePath(query: String) -> String {
        "search/issues?q=\(GitHubPaths.encodeQueryValue(query))"
            + "&sort=updated&order=desc&per_page=\(PAGE_SIZE)"
    }
}

enum ReviewQueueParser {
    static let REPOSITORY_PREFIX = "https://api.github.com/repos/"

    static func parseQueue(_ json_Data: Data) throws -> ReviewQueue {
        let payload = try JSONDecoder().decode(
            SearchPayload.self,
            from: json_Data
        )
        return ReviewQueue(
            total_Count: payload.total_Count,
            requests: payload.items.compactMap(makeRequest)
        )
    }

    /// Drafts are not ready for review yet, so they are left out.
    static func makeRequest(
        _ item: SearchItemPayload
    ) -> ReviewRequest? {
        guard item.draft != true,
            let repository = parseRepository(item.repository_URL)
        else { return nil }
        var request = ReviewRequest(
            repository: repository,
            number: item.number,
            title: item.title
        )
        request.author_Login = item.user?.login ?? ""
        request.page_URL = item.html_URL
        return request
    }

    /// "https://api.github.com/repos/owner/name" to owner/name.
    static func parseRepository(
        _ api_URL: String
    ) -> GitHubRepository? {
        guard api_URL.hasPrefix(REPOSITORY_PREFIX) else { return nil }
        let parts = api_URL.dropFirst(REPOSITORY_PREFIX.count)
            .split(separator: "/")
        guard parts.count == 2 else { return nil }
        return GitHubRepository(
            owner: String(parts[0]),
            name: String(parts[1])
        )
    }
}

struct SearchItemPayload: Decodable {
    let number: Int
    let title: String
    let draft: Bool?
    let html_URL: URL?
    let repository_URL: String
    let user: ReviewerPayload?

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case draft
        case html_URL = "html_url"
        case repository_URL = "repository_url"
        case user
    }
}

struct SearchPayload: Decodable {
    let total_Count: Int
    let items: [SearchItemPayload]

    enum CodingKeys: String, CodingKey {
        case total_Count = "total_count"
        case items
    }
}
