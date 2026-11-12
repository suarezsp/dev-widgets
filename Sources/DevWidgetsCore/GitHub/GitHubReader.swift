import Foundation

/// Pull request and CI of the chosen project's current branch.
/// Three requests at most: the PR, the workflow runs and, when
/// there is a PR, its reviews.
public struct GitHubReader: Sendable {
    public static let RUN_PAGE_SIZE = 20
    /// Branch names may hold "/", but never query separators.
    static let QUERY_VALUE_CHARACTERS = CharacterSet.urlQueryAllowed
        .subtracting(CharacterSet(charactersIn: "&+=#?"))

    /// nil when the user has neither a token nor a signed-in `gh`.
    public let client: GitHubClient?

    public init(client: GitHubClient?) {
        self.client = client
    }

    public func readState(git: GitState) async -> GitHubState {
        guard case .available(let git_Status) = git,
            let branch_Name = git_Status.branch.name,
            let remote_URL = git_Status.remote_URL
        else { return .not_Configured }
        guard
            let repository = GitRemoteParser.parseRepository(
                remote_URL: remote_URL,
                host: client?.host ?? .PUBLIC
            )
        else { return .not_GitHub }
        guard let client else { return .no_Credentials }
        do {
            let status = try await readStatus(
                of: repository,
                branch_Name: branch_Name,
                client: client
            )
            return .available(status: status)
        } catch {
            return Self.describe(error)
        }
    }

    func readStatus(
        of repository: GitHubRepository,
        branch_Name: String,
        client: GitHubClient
    ) async throws -> GitHubStatus {
        let paths = GitHubPaths(
            repository: repository,
            branch_Name: branch_Name
        )
        async let runs_Data = client.fetch(paths.workflow_Runs)
        let pull_Request = try await readPullRequest(
            paths: paths,
            client: client
        )
        var status = GitHubStatus(
            repository: repository,
            branch_Name: branch_Name,
            runs: try GitHubParser.parseRuns(try await runs_Data)
        )
        status.pull_Request = pull_Request
        return status
    }

    func readPullRequest(
        paths: GitHubPaths,
        client: GitHubClient
    ) async throws -> PullRequestSummary? {
        var pull_Request = try GitHubParser.parsePullRequest(
            try await client.fetch(paths.pull_Request)
        )
        if let number = pull_Request?.number {
            pull_Request?.review =
                try GitHubParser.parseReviewDecision(
                    try await client.fetch(paths.reviews(number))
                )
        }
        return pull_Request
    }

    /// Also used for the review queue, which fails the same ways.
    public static func describe(_ error: Error) -> GitHubState {
        switch error as? GitHubError {
        case .no_Credentials: .no_Credentials
        case .unauthorized: .unauthorized
        case .rate_Limited(let reset_At):
            .rate_Limited(reset_At: reset_At)
        case .not_Found:
            .unavailable(reason: "Repository not found or private")
        case .unreachable(let reason): .unavailable(reason: reason)
        case nil: .unavailable(reason: "Unexpected answer")
        }
    }
}

/// REST paths for one repository and branch.
struct GitHubPaths {
    static func encodeQueryValue(_ value: String) -> String {
        value.addingPercentEncoding(
            withAllowedCharacters: GitHubReader.QUERY_VALUE_CHARACTERS
        ) ?? value
    }

    let repository: GitHubRepository
    let branch_Name: String

    private var encoded_Branch: String {
        Self.encodeQueryValue(branch_Name)
    }

    /// Only pull requests from this repository, not from forks.
    var pull_Request: String {
        "repos/\(repository.full_Name)/pulls?state=open&per_page=1"
            + "&head=\(repository.owner):\(encoded_Branch)"
    }

    var workflow_Runs: String {
        "repos/\(repository.full_Name)/actions/runs"
            + "?per_page=\(GitHubReader.RUN_PAGE_SIZE)"
            + "&branch=\(encoded_Branch)"
    }

    func reviews(_ number: Int) -> String {
        "repos/\(repository.full_Name)/pulls/\(number)/reviews"
            + "?per_page=100"
    }
}
