import Foundation

/// What the developer-context widget shows: containers, listening
/// ports and the chosen project's Git status.
public struct DeveloperContext: Codable, Equatable, Sendable {
    public static let FILE_NAME = "developer-context.json"

    public let captured_At: Date
    public let docker: DockerState
    public let ports: [ListeningPort]
    public let git: GitState
    /// Read on its own, slower schedule and attached by the app.
    public var github = GitHubState.not_Configured
    /// Pull requests awaiting the user's review, any repository.
    public var review_Queue = ReviewQueueState.not_Loaded

    public init(
        docker: DockerState,
        ports: [ListeningPort],
        git: GitState
    ) {
        captured_At = Date()
        self.docker = docker
        self.ports = ports
        self.git = git
    }
}

public typealias ContextStore = JSONFileStore<DeveloperContext>

extension JSONFileStore where Value == DeveloperContext {
    public init(directory: URL) {
        self.init(directory: directory, file_Name: Value.FILE_NAME)
    }
}

/// Where listening ports come from on each platform.
public enum PortSource: Sendable {
    /// Linux: `/proc/net/tcp{,6}` and `/proc/[pid]/fd`.
    case proc_Tree(URL)
    /// macOS: the `lsof` command.
    case lsof(URL?)

    #if os(Linux)
    public static let PLATFORM_DEFAULT =
        PortSource.proc_Tree(
            URL(fileURLWithPath: "/proc")
        )
    #else
    public static let PLATFORM_DEFAULT = PortSource.lsof(
        ExecutableSearch.locate("lsof")
    )
    #endif
}

/// Reads the whole developer context. It runs programs that can
/// take seconds, so callers keep it off the main thread and run it
/// far less often than the per-second metrics.
public struct DeveloperContextReader: Sendable {
    public static let INTERVAL_SECONDS = 10.0

    public let runner: CommandRunner
    public let port_Source: PortSource

    public init(
        runner: CommandRunner = ProcessCommandRunner(),
        port_Source: PortSource = .PLATFORM_DEFAULT
    ) {
        self.runner = runner
        self.port_Source = port_Source
    }

    /// Blocking: Docker alone takes about two seconds.
    public func read(project_URL: URL?) -> DeveloperContext {
        DeveloperContext(
            docker: DockerReader(runner: runner).readState(),
            ports: PortList.merge(readPorts()),
            git: GitReader(runner: runner)
                .readState(project_URL: project_URL)
        )
    }

    func readPorts() -> [ListeningPort] {
        switch port_Source {
        case .proc_Tree(let proc_Directory):
            return LinuxPortReader(proc_Directory: proc_Directory)
                .readPorts()
        case .lsof(let lsof_URL):
            guard let lsof_URL else { return [] }
            let command = Command(
                executable_URL: lsof_URL,
                arguments: LsofParser.ARGUMENTS
            )
            let lsof_Text = (try? runner.run(command)) ?? ""
            return LsofParser.parsePorts(lsof_Text: lsof_Text)
        }
    }
}

extension DeveloperContextReader {
    /// The same read, awaited without holding a thread of Swift
    /// concurrency's pool for those seconds.
    public func readInBackground(
        project_URL: URL?
    ) async -> DeveloperContext {
        await BlockingWork.perform { read(project_URL: project_URL) }
    }
}
