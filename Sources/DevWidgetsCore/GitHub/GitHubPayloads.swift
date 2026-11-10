import Foundation

// The parts of GitHub REST responses DevWidgets reads. `gh api`
// prints the same JSON, so both transports share these payloads.

struct PullRequestPayload: Decodable {
    let number: Int
    let title: String
    let draft: Bool?
    let html_URL: URL?

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case draft
        case html_URL = "html_url"
    }
}

struct WorkflowRunPayload: Decodable {
    let run_ID: Int64
    let name: String?
    let status: String?
    let conclusion: String?
    let head_SHA: String
    let html_URL: URL?

    enum CodingKeys: String, CodingKey {
        case run_ID = "id"
        case name
        case status
        case conclusion
        case head_SHA = "head_sha"
        case html_URL = "html_url"
    }
}

struct WorkflowRunsPayload: Decodable {
    let workflow_Runs: [WorkflowRunPayload]

    enum CodingKeys: String, CodingKey {
        case workflow_Runs = "workflow_runs"
    }
}

struct ReviewerPayload: Decodable {
    let login: String
}

struct ReviewPayload: Decodable {
    let user: ReviewerPayload?
    let state: String
}
