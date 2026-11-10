import Foundation
@testable import DevWidgetsCore

/// Recorded `/proc` files used by parser and reader tests.
enum Fixtures {
    static let ROOT_DIRECTORY = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
    static let PROC_DIRECTORY =
        ROOT_DIRECTORY
        .appendingPathComponent("proc")
    static let SYS_DIRECTORY =
        ROOT_DIRECTORY
        .appendingPathComponent("sys")

    /// A fixture outside `proc`, e.g. "docker/ps.jsonl".
    static func rootText(_ relative_Path: String) throws -> String {
        let file_URL = ROOT_DIRECTORY.appendingPathComponent(
            relative_Path
        )
        return try String(contentsOf: file_URL, encoding: .utf8)
    }

    static func text(_ relative_Path: String) throws -> String {
        let file_URL =
            PROC_DIRECTORY
            .appendingPathComponent(relative_Path)
        return try String(contentsOf: file_URL, encoding: .utf8)
    }
}

/// Builds small raw samples so tests only state what matters.
enum SampleFactory {
    static let GIGABYTE: UInt64 = 1 << 30

    static func makeSample(
        busy_Ticks: UInt64,
        received_Bytes: UInt64,
        read_Bytes: UInt64?
    ) -> RawSample {
        let ticks = CPUTicks(
            busy_Ticks: busy_Ticks,
            idle_Ticks: 1_000
        )
        let io_Counters = read_Bytes.map {
            DiskIOCounters(read_Bytes: $0, written_Bytes: $0 / 2)
        }
        return RawSample(
            cpu: CPUSample(total: ticks, cores: [ticks, ticks]),
            memory: makeMemory(used_Gigabytes: 8),
            disk: DiskSample(
                space: Capacity(used_Bytes: 1, total_Bytes: 4),
                io_Counters: io_Counters
            ),
            network: NetworkCounters(
                received_Bytes: received_Bytes,
                sent_Bytes: received_Bytes / 4
            )
        )
    }

    static func makeMemory(used_Gigabytes: UInt64) -> MemoryUsage {
        MemoryUsage(
            physical: Capacity(
                used_Bytes: used_Gigabytes * GIGABYTE,
                total_Bytes: 16 * GIGABYTE
            ),
            swap: Capacity(used_Bytes: 0, total_Bytes: 0),
            pressure: .normal
        )
    }

    static func makeTimedSample(
        _ sample: RawSample,
        seconds_After_Start: Double
    ) -> TimedSample {
        let start_Date = Date(timeIntervalSinceReferenceDate: 0)
        return TimedSample(
            sample: sample,
            captured_At: start_Date.addingTimeInterval(
                seconds_After_Start
            )
        )
    }

    static func makeInterval(
        from old_Sample: RawSample,
        to new_Sample: RawSample,
        elapsed_Seconds: Double
    ) -> SampleInterval {
        SampleInterval(
            from: makeTimedSample(old_Sample, seconds_After_Start: 0),
            to: makeTimedSample(
                new_Sample,
                seconds_After_Start: elapsed_Seconds
            )
        )
    }
}

/// Answers commands with recorded output, keyed by the first
/// argument ("ps", "stats", "status"), and records what was run.
/// Locked: `runInBackground` calls it from Dispatch threads.
final class FakeCommandRunner: CommandRunner, @unchecked Sendable {
    let outputs: [String: String]
    private let lock = NSLock()
    private var recorded_Commands: [Command] = []

    init(outputs: [String: String]) {
        self.outputs = outputs
    }

    var run_Commands: [Command] {
        lock.withLock { recorded_Commands }
    }

    func run(_ command: Command) throws -> String {
        lock.withLock { recorded_Commands.append(command) }
        guard let output = outputs[command.arguments.first ?? ""]
        else {
            throw CommandError.failed(
                exit_Status: 1,
                error_Text: "fake"
            )
        }
        return output
    }
}

/// Answers GitHub paths with fixture files: the first rule whose
/// fragment the path contains wins. Records every path asked.
final class FakeGitHubTransport: GitHubTransport, @unchecked Sendable
{
    let rules: [(fragment: String, file_Name: String)]
    var failure: GitHubError?
    private let lock = NSLock()
    private var fetched_Paths: [String] = []
    private var sent_ETags: [String?] = []

    init(rules: [(fragment: String, file_Name: String)]) {
        self.rules = rules
    }

    var paths: [String] { lock.withLock { fetched_Paths } }
    var etags: [String?] { lock.withLock { sent_ETags } }

    /// Every page gets the ETag "e:<file>"; a request that sends
    /// it back is answered 304, as GitHub does.
    func fetch(
        _ path: String,
        etag: String?
    ) async throws -> GitHubPage {
        lock.withLock {
            fetched_Paths.append(path)
            sent_ETags.append(etag)
        }
        if let failure { throw failure }
        guard
            let rule = rules.first(where: {
                path.contains($0.fragment)
            })
        else { throw GitHubError.not_Found }
        let page_ETag = "e:\(rule.file_Name)"
        guard etag != page_ETag else { return .not_Modified }
        let body = try Fixtures.rootText("github/\(rule.file_Name)")
        return .modified(body: Data(body.utf8), etag: page_ETag)
    }
}

/// Sleeps like a slow program, to show what blocks a thread.
struct SlowCommandRunner: CommandRunner {
    let seconds: Double

    func run(_ command: Command) throws -> String {
        Thread.sleep(forTimeInterval: seconds)
        return command.arguments.first ?? ""
    }
}
