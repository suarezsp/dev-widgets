#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// One external program run: docker, git or lsof.
public struct Command: Equatable, Sendable {
    public let executable_URL: URL
    public let arguments: [String]
    public var working_Directory: URL?
    /// Overrides the runner's default for slow commands.
    public var timeout_Seconds: Double?

    public init(executable_URL: URL, arguments: [String]) {
        self.executable_URL = executable_URL
        self.arguments = arguments
    }
}

public enum CommandError: Error, Equatable {
    /// The program exited with a non-zero status.
    case failed(exit_Status: Int32, error_Text: String)
    case timed_Out(seconds: Double)
}

/// Runs a command and returns its standard output. The only
/// protocol of this module besides `RawSampleReader`: tests
/// replace real programs with recorded output.
public protocol CommandRunner: Sendable {
    func run(_ command: Command) throws -> String
}

/// Finds programs without relying on `PATH`: a menu bar app
/// launched by macOS gets a minimal one without Homebrew.
public enum ExecutableSearch {
    public static let DIRECTORIES = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
        "/usr/sbin",
        "/Applications/Docker.app/Contents/Resources/bin",
    ]

    public static func locate(
        _ name: String,
        in directories: [String] = DIRECTORIES
    ) -> URL? {
        directories
            .map {
                URL(fileURLWithPath: $0).appendingPathComponent(name)
            }
            .first {
                FileManager.default.isExecutableFile(atPath: $0.path)
            }
    }
}
