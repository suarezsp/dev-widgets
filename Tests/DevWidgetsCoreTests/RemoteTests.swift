import Foundation
import Testing
@testable import DevWidgetsCore

struct RemoteProbeTests {
    static func readSnapshot(_ name: String) throws -> RemoteSnapshot
    {
        try RemoteProbe.parseSnapshot(
            try Fixtures.rootText("ssh/\(name)")
        )
    }

    @Test func recordedLinuxAnswerIsParsed() throws {
        let snapshot = try Self.readSnapshot("probe-linux-1.txt")
        #expect(snapshot.cpu.cores.count == 8)
        #expect(snapshot.memory.physical.total_Bytes > 1 << 30)
        #expect(snapshot.disk_Space.used_Fraction > 0)
        #expect(snapshot.disk_Space.used_Fraction < 1)
        #expect(snapshot.load_Average != nil)
        #expect((snapshot.uptime_Seconds ?? 0) > 0)
        #expect(snapshot.network.received_Bytes > 0)
        #expect(snapshot.system_Text.hasPrefix("Linux "))
    }

    @Test func serverWithoutProcIsNotLinux() {
        #expect(throws: RemoteProblem.not_Linux(system: "Darwin")) {
            try Self.readSnapshot("probe-darwin.txt")
        }
    }

    @Test func emptyAnswerNamesNoSystem() {
        #expect(
            throws: RemoteProblem.not_Linux(system: "Unknown system")
        ) {
            try RemoteProbe.parseSnapshot("")
        }
    }

    @Test func scriptRunsInPosixShell() {
        let script = RemoteProbe.makeScript(disk_Path: "/srv/data")
        #expect(script.hasPrefix("exec sh -c '"))
        #expect(script.hasSuffix("uname -snr'"))
        #expect(script.contains("df -kP /srv/data;"))
        #expect(script.filter { $0 == "'" }.count == 2)
    }

    @Test(arguments: [
        ("error-host-key.txt", RemoteProblem.host_Key_Rejected),
        ("error-permission-denied.txt", .authentication_Failed),
        ("error-password-only.txt", .interactive_Login_Required),
        ("error-key-then-password.txt", .interactive_Login_Required),
        (
            "error-connection-refused.txt",
            .unreachable(reason: "Connection refused")
        ),
    ])
    func recordedSSHErrorsAreClassified(
        file_Name: String,
        problem: RemoteProblem
    ) throws {
        let error_Text = try Fixtures.rootText("ssh/\(file_Name)")
        #expect(SSHErrorParser.classify(error_Text) == problem)
    }
}

struct RemoteHostTests {
    @Test(arguments: ["web-1", "deploy@10.0.0.4", " db "])
    func aliasesAreAccepted(alias: String) {
        #expect(RemoteHost(alias: alias) != nil)
    }

    @Test(arguments: ["", "-oProxyCommand=sh", "web 1", "a\tb"])
    func optionLikeOrSpacedAliasesAreRefused(alias: String) {
        #expect(RemoteHost(alias: alias) == nil)
    }

    @Test func configSuggestsNamedHostsOnly() throws {
        let config_Text = try Fixtures.rootText(
            "ssh/config-sample.txt"
        )
        #expect(
            SSHConfigParser.listAliases(config_Text: config_Text)
                == ["web-1", "web-2", "db", "bastion"]
        )
    }

    @Test func argumentsNeverPromptAndEndWithScript() throws {
        var options = SSHOptions()
        options.config_File = URL(fileURLWithPath: "/tmp/config")
        options.control_Directory = URL(fileURLWithPath: "/tmp/cm")
        let host = try RemoteSamples.makeHost("web-1")
        let arguments = options.makeArguments(host: host)
        #expect(arguments.contains("BatchMode=yes"))
        #expect(arguments.contains("ControlPath=/tmp/cm/%C"))
        let separator_Index = try #require(
            arguments.firstIndex(of: "--")
        )
        #expect(
            Array(arguments[separator_Index...])
                == [
                    "--", "web-1",
                    RemoteProbe.makeScript(disk_Path: "/"),
                ]
        )
        #expect(arguments.contains("/tmp/config"))
    }

    @Test(arguments: ["/", "/var/lib/docker", "/mnt/data_2"])
    func plainDiskPathsAreAccepted(disk_Path: String) {
        #expect(
            RemoteHost(alias: "web-1", disk_Path: disk_Path) != nil
        )
    }

    @Test(arguments: [
        "", "var", "/tmp'; rm -rf ~; '", "/a b", "/$HOME", "/x;id",
    ])
    func unsafeDiskPathsAreRefused(disk_Path: String) {
        #expect(
            RemoteHost(alias: "web-1", disk_Path: disk_Path) == nil
        )
    }

    @Test func hostsSavedWithoutDiskReadRoot() throws {
        let json_Data = Data(#"{"alias": "web-1"}"#.utf8)
        let host = try JSONDecoder().decode(
            RemoteHost.self,
            from: json_Data
        )
        #expect(host.disk_Path == "/")
        let unsafe_Data = Data(
            #"{"alias": "web-1", "disk_Path": "/;id"}"#.utf8
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                RemoteHost.self,
                from: unsafe_Data
            )
        }
    }

    @Test func damagedSettingsDoNotDecode() {
        let json_Data = Data(#"{"alias": "-oProxyCommand=sh"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RemoteHost.self, from: json_Data)
        }
    }

    @Test func sharingDirectoryMustBePrivate() throws {
        let directory_URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dw-open-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory_URL,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o755]
        )
        defer {
            try? FileManager.default.removeItem(at: directory_URL)
        }
        #expect(!SSHConnectionSharing.isPrivate(directory_URL))
        #expect(SSHConnectionSharing.prepareDirectory() != nil)
    }
}
