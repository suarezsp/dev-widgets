#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// Asks a process to quit, never with SIGKILL, so it can save its
/// work: apps first get the platform's polite quit, everything else
/// SIGTERM. Refuses when the pid now belongs to another program, is
/// init, or is DevWidgets itself.
public struct ProcessTerminator: Sendable {
    /// Current name of a pid: `/proc` on Linux, libproc on macOS.
    public let name_Lookup: @Sendable (Int32) -> String?
    /// Quits the pid as an app (the Dock's Quit on macOS); false
    /// when it is not an app or did not take the request.
    public let app_Quitter: @Sendable (Int32) -> Bool

    public init(
        name_Lookup: @escaping @Sendable (Int32) -> String?,
        app_Quitter: @escaping @Sendable (Int32) -> Bool = { _ in
            false
        }
    ) {
        self.name_Lookup = name_Lookup
        self.app_Quitter = app_Quitter
    }

    public func terminate(_ process: ProcessIdentity) -> ActionOutcome
    {
        guard process.pid > 1, process.pid != getpid() else {
            return .refused(reason: "Protected process")
        }
        guard let current_Name = name_Lookup(process.pid),
            current_Name == process.name
        else {
            return .refused(reason: "\(process.name) already quit")
        }
        if app_Quitter(process.pid) { return .done }
        guard kill(process.pid, SIGTERM) != 0 else { return .done }
        return Self.describeSignalError(errno, name: process.name)
    }

    static func describeSignalError(
        _ error_Number: Int32,
        name: String
    ) -> ActionOutcome {
        switch error_Number {
        case EPERM:
            .failed(
                reason: "\(name) is not your process: only your own"
                    + " processes can be quit"
            )
        case ESRCH: .refused(reason: "\(name) already quit")
        default:
            .failed(reason: String(cString: strerror(error_Number)))
        }
    }
}

/// `docker stop` and `docker restart`: SIGTERM, then SIGKILL after
/// the grace period, exactly as on the command line.
public struct ContainerController: Sendable {
    public static let GRACE_SECONDS = 10
    /// The grace period plus time for Docker to answer (and, for a
    /// restart, to start the container again).
    static let TIMEOUT_SECONDS = 30.0

    public let runner: CommandRunner
    public let docker_URL: URL?

    public init(
        runner: CommandRunner,
        docker_URL: URL? = ExecutableSearch.locate("docker")
    ) {
        self.runner = runner
        self.docker_URL = docker_URL
    }

    public func stop(
        _ container: ContainerIdentity
    ) async -> ActionOutcome {
        await run("stop", container: container)
    }

    public func restart(
        _ container: ContainerIdentity
    ) async -> ActionOutcome {
        await run("restart", container: container)
    }

    func run(
        _ verb: String,
        container: ContainerIdentity
    ) async -> ActionOutcome {
        guard let docker_URL else {
            return .failed(reason: "Docker not found")
        }
        var command = Command(
            executable_URL: docker_URL,
            arguments: [
                verb, "--time", "\(Self.GRACE_SECONDS)",
                container.container_ID,
            ]
        )
        command.timeout_Seconds = Self.TIMEOUT_SECONDS
        do {
            _ = try await runner.runInBackground(command)
            return .done
        } catch CommandError.failed(_, let error_Text) {
            return .failed(reason: Self.firstLine(error_Text, verb))
        } catch {
            return .failed(reason: "Docker did not answer in time")
        }
    }

    static func firstLine(_ text: String, _ verb: String) -> String {
        text.split(separator: "\n").first.map(String.init)
            ?? "docker \(verb) failed"
    }
}
