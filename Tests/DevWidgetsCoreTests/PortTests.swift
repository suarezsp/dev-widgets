import Foundation
import Testing
@testable import DevWidgetsCore

struct PortTests {
    @Test func procTablesGiveListeningSocketsOnly() throws {
        let entries = ProcNetParser.parseListening(
            table_Text: try Fixtures.text("net/tcp")
        )
        #expect(
            entries == [
                SocketEntry(
                    port: 5432,
                    address: "127.0.0.1",
                    inode: "91001"
                ),
                SocketEntry(port: 3000, address: "*", inode: "91002"),
            ]
        )
    }

    @Test func ipv6AddressesAreDecoded() throws {
        let entries = ProcNetParser.parseListening(
            table_Text: try Fixtures.text("net/tcp6")
        )
        #expect(entries.map(\.address) == ["*", "::1"])
        #expect(entries.map(\.port) == [3000, 8080])
    }

    @Test func ownersComeFromDescriptorLinks() {
        let ports = PortList.merge(
            LinuxPortReader(proc_Directory: Fixtures.PROC_DIRECTORY)
                .readPorts()
        )
        #expect(ports.map(\.port) == [3000, 5432, 8080])
        #expect(ports[0].owner?.name == "Web Content (2)")
        #expect(ports[1].owner == nil)
        #expect(ports[2].owner?.name == "swift-build")
        #expect(ports[2].is_Local_Only)
    }

    /// lsof output is hand-written: it is the macOS source.
    @Test func lsofFieldsGivePortsWithOwners() throws {
        let ports = PortList.merge(
            LsofParser.parsePorts(
                lsof_Text: try Fixtures.rootText("lsof/listen.txt")
            )
        )
        #expect(ports.map(\.port) == [5173, 5432, 7000])
        #expect(
            ports.map(\.owner?.name) == [
                "node", "postgres", "ControlCe",
            ]
        )
        #expect(ports[0].address == "*")
        #expect(ports[1].address == "127.0.0.1")
    }

    @Test func badLsofAddressesAreSkipped() {
        let ports = LsofParser.parsePorts(
            lsof_Text: "p1\ncx\nnnoport\n"
        )
        #expect(ports.isEmpty)
    }

    @Test func programNameComesFromCommandLine() {
        let program_Name = LinuxPortReader.parseProgramName(
            "/usr/bin/python3\0-m\0http.server"
        )
        #expect(program_Name == "python3")
        #expect(LinuxPortReader.parseProgramName("") == nil)
    }

    @Test(arguments: [
        ("sshd: /usr/sbin/sshd -D [listener] 0 of 10-100", "sshd"),
        ("postgres: checkpointer ", "postgres"),
        ("/opt/google/chrome/chrome --type=renderer", "chrome"),
        ("node\0server.js", "node"),
    ])
    func retitledProcessesKeepTheirProgram(
        _ command_Line: String,
        _ expected_Name: String
    ) {
        #expect(
            LinuxPortReader.parseProgramName(command_Line)
                == expected_Name
        )
    }

    @Test func socketLinkTargetsAreParsed() {
        #expect(
            LinuxPortReader.parseSocketInode("socket:[5746]")
                == "5746"
        )
        #expect(LinuxPortReader.parseSocketInode("/dev/null") == nil)
    }

    #if os(Linux)
    @Test func thisMachineListsItsPorts() {
        let reader = DeveloperContextReader()
        #expect(!reader.readPorts().isEmpty)
    }
    #endif
}
