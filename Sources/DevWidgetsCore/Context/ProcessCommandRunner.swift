#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// Runs real programs with `Foundation.Process`. Output goes to
/// temporary files rather than pipes, so a chatty program can never
/// block on a full pipe, and a hung one is stopped after a timeout.
public struct ProcessCommandRunner: CommandRunner {
    public static let DEFAULT_TIMEOUT_SECONDS = 5.0
    static let POLL_MICROSECONDS: UInt32 = 10_000
    /// Time a timed-out program gets to honour SIGTERM.
    static let KILL_GRACE_SECONDS = 1.0

    public let timeout_Seconds: Double

    public init(timeout_Seconds: Double = DEFAULT_TIMEOUT_SECONDS) {
        self.timeout_Seconds = timeout_Seconds
    }

    public func run(_ command: Command) throws -> String {
        let output_File = try TemporaryOutputFile()
        let error_File = try TemporaryOutputFile()
        defer {
            output_File.remove()
            error_File.remove()
        }
        let process = Self.makeProcess(command)
        process.standardOutput = output_File.handle
        process.standardError = error_File.handle
        try process.run()
        try waitForExit(
            of: process,
            timeout_Seconds: command.timeout_Seconds
                ?? timeout_Seconds
        )
        guard process.terminationStatus == 0 else {
            throw CommandError.failed(
                exit_Status: process.terminationStatus,
                error_Text: error_File.readText()
            )
        }
        return output_File.readText()
    }

    static func makeProcess(_ given_Command: Command) -> Process {
        let command = FlatpakHost.route(given_Command)
        let process = Process()
        process.executableURL = command.executable_URL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.working_Directory
        return process
    }

    /// SIGTERM first; SIGKILL when the program ignores or blocks
    /// it, so a hung command never outlives the timeout.
    private func waitForExit(
        of process: Process,
        timeout_Seconds: Double
    ) throws {
        if waitUntilExit(process, seconds: timeout_Seconds) { return }
        process.terminate()
        if !waitUntilExit(process, seconds: Self.KILL_GRACE_SECONDS) {
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
        throw CommandError.timed_Out(seconds: timeout_Seconds)
    }

    /// True when the process exited within `seconds`.
    private func waitUntilExit(
        _ process: Process,
        seconds: Double
    ) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while process.isRunning {
            guard Date() < deadline else { return false }
            usleep(Self.POLL_MICROSECONDS)
        }
        return true
    }
}

/// A uniquely named file in the temporary directory.
struct TemporaryOutputFile {
    let file_URL: URL
    let handle: FileHandle

    init() throws {
        file_URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("devwidgets-\(UUID().uuidString)")
        _ = FileManager.default.createFile(
            atPath: file_URL.path,
            contents: nil
        )
        handle = try FileHandle(forWritingTo: file_URL)
    }

    func readText() -> String {
        let data = (try? Data(contentsOf: file_URL)) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    func remove() {
        try? handle.close()
        try? FileManager.default.removeItem(at: file_URL)
    }
}
