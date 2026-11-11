#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// How DevWidgets calls the system `ssh`.
public struct SSHOptions: Sendable {
    /// Connection timeout plus a slow server's answer.
    public static let TIMEOUT_SECONDS = 15.0
    public static let CONNECT_TIMEOUT_SECONDS = 5
    /// How long the shared connection outlives the last poll.
    public static let PERSIST_SECONDS = 120

    /// nil: the user's own `~/.ssh/config`. Tests point it at a
    /// throwaway config for a local `sshd`.
    public var config_File: URL?
    /// Where shared-connection sockets live; nil turns sharing
    /// off.
    public var control_Directory: URL?

    public init() {}

    /// BatchMode: never ask for a password or a host key, fail.
    /// Connection sharing: one login per host every 2 minutes
    /// instead of one per poll, so the server's auth log stays
    /// quiet.
    func makeArguments(host: RemoteHost) -> [String] {
        var arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(Self.CONNECT_TIMEOUT_SECONDS)",
            "-o", "ServerAliveInterval=5",
            "-o", "ServerAliveCountMax=2",
        ]
        if let control_Directory {
            arguments += [
                "-o", "ControlMaster=auto",
                "-o", "ControlPath=\(control_Directory.path)/%C",
                "-o", "ControlPersist=\(Self.PERSIST_SECONDS)",
            ]
        }
        if let config_File { arguments += ["-F", config_File.path] }
        let script = RemoteProbe.makeScript(disk_Path: host.disk_Path)
        return arguments + ["-T", "--", host.alias, script]
    }
}

/// One `ssh` round trip per host, all hosts in parallel, without
/// blocking Swift concurrency's threads.
public struct SSHReader: Sendable {
    public let runner: CommandRunner
    public let ssh_URL: URL?
    public var options = SSHOptions()

    public init(
        runner: CommandRunner = ProcessCommandRunner(),
        ssh_URL: URL? = ExecutableSearch.locate("ssh")
    ) {
        self.runner = runner
        self.ssh_URL = ssh_URL
    }

    public func read(
        _ host: RemoteHost
    ) async -> Result<RemoteSnapshot, RemoteProblem> {
        guard let ssh_URL else { return .failure(.ssh_Missing) }
        var command = Command(
            executable_URL: ssh_URL,
            arguments: options.makeArguments(host: host)
        )
        command.timeout_Seconds = SSHOptions.TIMEOUT_SECONDS
        do {
            let output = try await runner.runInBackground(command)
            return Result { () throws(RemoteProblem) in
                try RemoteProbe.parseSnapshot(output)
            }
        } catch CommandError.failed(_, let error_Text) {
            return .failure(SSHErrorParser.classify(error_Text))
        } catch {
            return .failure(.unreachable(reason: "No answer in 15 s"))
        }
    }

    public func readAll(
        _ hosts: [RemoteHost]
    ) async -> [RemoteHost: Result<RemoteSnapshot, RemoteProblem>] {
        await withTaskGroup { group in
            for host in hosts {
                group.addTask { (host, await read(host)) }
            }
            var results:
                [RemoteHost: Result<RemoteSnapshot, RemoteProblem>] =
                    [:]
            for await (host, result) in group {
                results[host] = result
            }
            return results
        }
    }
}

/// Reads `ssh`'s own messages (exit status 255).
enum SSHErrorParser {
    static func classify(_ error_Text: String) -> RemoteProblem {
        if error_Text.contains("Host key verification failed")
            || error_Text.contains("REMOTE HOST IDENTIFICATION")
        {
            return .host_Key_Rejected
        }
        if error_Text.contains(DENIED_TEXT) {
            return findMethods(error_Text).contains("publickey")
                ? .authentication_Failed : .interactive_Login_Required
        }
        return .unreachable(reason: findReason(error_Text))
    }

    static let DENIED_TEXT = "Permission denied ("

    /// "Permission denied (publickey,password)." lists what the
    /// server still accepts. Without "publickey" it wants a
    /// password or a second factor, even after a key was accepted.
    static func findMethods(_ error_Text: String) -> [Substring] {
        guard let start = error_Text.range(of: DENIED_TEXT),
            let end = error_Text[start.upperBound...].firstIndex(
                of: ")"
            )
        else { return ["publickey"] }
        return error_Text[start.upperBound..<end].split(
            separator: ","
        )
    }

    /// "ssh: connect to host 10.0.0.9 port 22: Connection refused"
    /// becomes "Connection refused". Warnings come first, so the
    /// last line is the error.
    static func findReason(_ error_Text: String) -> String {
        let last_Line =
            error_Text.split(separator: "\n")
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .last { !$0.isEmpty } ?? ""
        let reason_Text = last_Line.split(separator: ":").last
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return reason_Text.flatMap { $0.isEmpty ? nil : $0 }
            ?? "ssh failed"
    }
}

/// The socket directory for shared connections: private to the
/// user, short enough for the 104-byte socket path limit of macOS
/// (the cache folder under `~/Library` is too long).
public enum SSHConnectionSharing {
    public static func prepareDirectory() -> URL? {
        let directory_URL = URL(
            fileURLWithPath: "/tmp/devwidgets-ssh-\(getuid())"
        )
        let file_Manager = FileManager.default
        try? file_Manager.createDirectory(
            at: directory_URL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return isPrivate(directory_URL) ? directory_URL : nil
    }

    /// Someone else could have created the folder first: sharing
    /// is only used when it is ours and closed to others.
    static func isPrivate(_ directory_URL: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(
            atPath: directory_URL.path
        )
        let owner_ID = attributes?[.ownerAccountID] as? NSNumber
        let permissions = attributes?[.posixPermissions] as? NSNumber
        return owner_ID?.uint32Value == getuid()
            && permissions?.intValue == 0o700
    }
}
