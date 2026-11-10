import DevWidgetsCore

/// Plausible developer context for the widget gallery and Xcode
/// previews. Never shown on a placed widget.
extension PreviewData {
    static let CONTEXT = makeContext()

    static func makeContext() -> DeveloperContext {
        var context = DeveloperContext(
            docker: .available(containers: makeContainers()),
            ports: makePorts(),
            git: .available(status: makeGitStatus())
        )
        context.github = .available(status: makeGitHubStatus())
        context.review_Queue = .available(queue: makeReviewQueue())
        return context
    }

    static func makeGitHubStatus() -> GitHubStatus {
        var status = GitHubStatus(
            repository: GitHubRepository(
                owner: "acme",
                name: "devwidgets"
            ),
            branch_Name: "feature/charts",
            runs: [
                WorkflowRunSummary(
                    run_ID: 1,
                    workflow_Name: "Tests",
                    outcome: .success
                )
            ]
        )
        var pull_Request = PullRequestSummary(
            number: 42,
            title: "History charts",
            is_Draft: false
        )
        pull_Request.review = .approved
        status.pull_Request = pull_Request
        return status
    }

    static func makeReviewQueue() -> ReviewQueue {
        let requests = [
            ("api", 318, "Retry failed uploads", "lucia"),
            ("web", 77, "Dark mode toggle", "marco"),
        ].map { name, number, title, author in
            var request = ReviewRequest(
                repository: GitHubRepository(
                    owner: "acme",
                    name: name
                ),
                number: number,
                title: title
            )
            request.author_Login = author
            return request
        }
        return ReviewQueue(total_Count: 3, requests: requests)
    }

    static let PREVIEW_CONTAINERS = [
        PreviewContainer(
            name: "api-web-1",
            image: "node:22",
            cpu: 0.12
        ),
        PreviewContainer(
            name: "api-db-1",
            image: "postgres:16",
            cpu: 0.04
        ),
        PreviewContainer(
            name: "api-cache-1",
            image: "redis:7",
            cpu: 0.01
        ),
    ]

    static func makeContainers() -> [ContainerUsage] {
        PREVIEW_CONTAINERS.enumerated().map { index, preview in
            var container = ContainerUsage(
                identity: ContainerIdentity(
                    container_ID: "3f1c2a9b7d1\(index)",
                    name: preview.name,
                    image: preview.image
                ),
                state: "running"
            )
            container.cpu_Fraction = preview.cpu
            container.memory_Bytes = UInt64(80 + 60 * index) << 20
            return container
        }
    }

    /// Program and its port; the process ID follows the program.
    static let PREVIEW_PORTS: [(name: String, port: UInt16)] = [
        ("node", 5173), ("node", 3000), ("postgres", 5432),
        ("redis-server", 6379), ("python3", 8000),
    ]

    static func makePorts() -> [ListeningPort] {
        PREVIEW_PORTS.map { name, port in
            ListeningPort(
                port: port,
                address: "127.0.0.1",
                owner: ProcessIdentity(
                    pid: Int32(800 + name.count),
                    name: name
                )
            )
        }
    }

    static func makeGitStatus() -> GitStatus {
        var branch = BranchStatus()
        branch.name = "feature/charts"
        branch.upstream = "origin/main"
        branch.ahead_Count = 2
        var changes = ChangeCounts()
        changes.modified = 3
        changes.untracked = 1
        return GitStatus(
            project_Name: "devwidgets",
            branch: branch,
            changes: changes
        )
    }
}

/// A running container in the preview context.
struct PreviewContainer {
    let name: String
    let image: String
    let cpu: Double
}
