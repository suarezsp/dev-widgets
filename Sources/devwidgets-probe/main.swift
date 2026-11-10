import DevWidgetsCore
import Foundation

#if os(macOS)
import DevWidgetsDarwin
#endif

// Samples this machine with DevWidgetsCore and prints JSON.
// Usage:
//   devwidgets-probe [sample_count]       metric snapshot, 1 per s
//   devwidgets-probe context [project]    developer context
//   devwidgets-probe github project [rest]
//       GitHub state of the project's branch, read twice to show
//       the ETag cache: through `gh` (or GITHUB_TOKEN), or with
//       "rest" through the REST API, anonymously unless
//       GITHUB_TOKEN is set.
//   devwidgets-probe reviews              review queue (@me)
//   devwidgets-probe servers [-F config] alias...
//       two polls of each host, 3 s apart, with the system ssh.

let DEFAULT_SAMPLE_COUNT = 2
let SAMPLE_INTERVAL_SECONDS: UInt32 = 1
let SERVER_POLL_GAP_SECONDS: UInt32 = 3
let CONTEXT_MODE = "context"
let GITHUB_MODE = "github"
let REVIEWS_MODE = "reviews"
let SERVERS_MODE = "servers"
let REST_OPTION = "rest"
let CONFIG_OPTION = "-F"

/// What the github mode prints: the state and the cache's effect.
struct GitHubProbeResult: Encodable {
    let state: GitHubState
    let request_Count: Int
    let not_Modified_Count: Int
}

func printJSON<Value: Encodable>(_ value: Value) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let json_Data = try encoder.encode(value)
    print(String(bytes: json_Data, encoding: .utf8) ?? "")
}

// The same reader the app of this system uses.
#if os(macOS)
typealias SystemSampleReader = DarwinSampleReader
#else
typealias SystemSampleReader = LinuxSampleReader
#endif

func sampleMetrics(count: Int) throws -> MetricSnapshot? {
    var monitor = MetricsMonitor(reader: SystemSampleReader())
    var latest_Snapshot: MetricSnapshot?
    for sample_Index in 0..<max(2, count) {
        if sample_Index > 0 { sleep(SAMPLE_INTERVAL_SECONDS) }
        latest_Snapshot = try monitor.sample() ?? latest_Snapshot
    }
    return latest_Snapshot
}

func makeClient(via_Rest: Bool) -> GitHubClient? {
    let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
    let transport =
        via_Rest
        ? RESTTransport(token: token)
        : GitHubTransportChoice.choose(token: token)
    return transport.map { GitHubClient(transport: $0) }
}

func readGitHub(
    project_Path: String,
    via_Rest: Bool
) async -> GitHubProbeResult {
    let client = makeClient(via_Rest: via_Rest)
    let git = GitReader(runner: ProcessCommandRunner())
        .readState(project_URL: URL(fileURLWithPath: project_Path))
    let reader = GitHubReader(client: client)
    _ = await reader.readState(git: git)
    let state = await reader.readState(git: git)
    return GitHubProbeResult(
        state: state,
        request_Count: await client?.request_Count ?? 0,
        not_Modified_Count: await client?.not_Modified_Count ?? 0
    )
}

func pollServers(_ server_Arguments: [String]) async -> ServerOverview
{
    var reader = SSHReader()
    var aliases = server_Arguments
    if aliases.first == CONFIG_OPTION, aliases.count >= 2 {
        reader.options.config_File = URL(fileURLWithPath: aliases[1])
        aliases.removeFirst(2)
    }
    reader.options.control_Directory =
        SSHConnectionSharing.prepareDirectory()
    let hosts = aliases.compactMap { RemoteHost(alias: $0) }
    var tracker = RemoteTracker()
    _ = tracker.update(
        hosts: hosts,
        results: await reader.readAll(hosts)
    )
    sleep(SERVER_POLL_GAP_SECONDS)
    return tracker.update(
        hosts: hosts,
        results: await reader.readAll(hosts)
    )
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case GITHUB_MODE where arguments.count >= 2:
    try printJSON(
        await readGitHub(
            project_Path: arguments[1],
            via_Rest: arguments.dropFirst(2).first == REST_OPTION
        )
    )
case REVIEWS_MODE:
    let client = makeClient(via_Rest: false)
    try printJSON(await ReviewQueueReader(client: client).readState())
case SERVERS_MODE:
    try printJSON(await pollServers(Array(arguments.dropFirst())))
case CONTEXT_MODE:
    let project_URL = arguments.dropFirst().first.map {
        URL(fileURLWithPath: $0)
    }
    try printJSON(
        DeveloperContextReader().read(project_URL: project_URL)
    )
default:
    let requested_Count =
        arguments.first.flatMap { Int($0) } ?? DEFAULT_SAMPLE_COUNT
    try printJSON(try sampleMetrics(count: requested_Count))
}
