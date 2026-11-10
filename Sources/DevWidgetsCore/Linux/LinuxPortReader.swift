import Foundation

/// Listening TCP ports from `/proc/net`, with their owner found by
/// matching socket inodes against `/proc/[pid]/fd`. Only the
/// user's own processes can be inspected; others stay anonymous.
struct LinuxPortReader {
    static let TABLE_NAMES = ["net/tcp", "net/tcp6"]

    let proc_Directory: URL

    func readPorts() -> [ListeningPort] {
        let entries = Self.TABLE_NAMES
            .compactMap {
                KernelFiles.readText(named: $0, in: proc_Directory)
            }
            .flatMap { ProcNetParser.parseListening(table_Text: $0) }
        guard !entries.isEmpty else { return [] }
        let owners = readSocketOwners()
        return entries.map {
            ListeningPort(
                port: $0.port,
                address: $0.address,
                owner: owners[$0.inode]
            )
        }
    }

    /// Socket inode -> process, from links like "socket:[5746]".
    func readSocketOwners() -> [String: ProcessIdentity] {
        var owners: [String: ProcessIdentity] = [:]
        for process_Directory in KernelFiles.listProcessDirectories(
            in: proc_Directory
        ) {
            guard let identity = readIdentity(process_Directory)
            else {
                continue
            }
            for inode in readSocketInodes(process_Directory) {
                owners[inode] = identity
            }
        }
        return owners
    }

    /// `comm` is cut at 15 characters and runtimes rename it (Node
    /// shows "MainThread"), so the program in `cmdline` wins.
    func readIdentity(_ process_Directory: URL) -> ProcessIdentity? {
        guard
            let process_ID = Int32(
                process_Directory.lastPathComponent
            )
        else { return nil }
        let command_Line = KernelFiles.readText(
            named: "cmdline",
            in: process_Directory
        )
        let program_Name = command_Line.flatMap(Self.parseProgramName)
        let short_Name = KernelFiles.readText(
            named: "comm",
            in: process_Directory
        ).map(SysfsParser.trimmed)
        guard let name = program_Name ?? short_Name else {
            return nil
        }
        return ProcessIdentity(pid: process_ID, name: name)
    }

    /// "/usr/bin/python3\0-m\0http.server" -> "python3". Daemons
    /// that retitle themselves write one string instead: "sshd:
    /// /usr/sbin/sshd -D [listener]", "postgres: checkpointer",
    /// "/opt/google/chrome/chrome --type=renderer".
    static func parseProgramName(_ command_Line: String) -> String? {
        guard
            let first_Argument = command_Line.split(separator: "\0")
                .first
        else { return nil }
        var program_Path = first_Argument.components(
            separatedBy: ": "
        )[0]
        if program_Path.hasPrefix("/"),
            let space_Index = program_Path.firstIndex(of: " ")
        {
            program_Path = String(program_Path[..<space_Index])
        }
        return program_Path.split(separator: "/").last.map(
            String.init
        )
    }

    func readSocketInodes(_ process_Directory: URL) -> [String] {
        let descriptor_Directory =
            process_Directory
            .appendingPathComponent("fd")
        return KernelFiles.listNames(in: descriptor_Directory)
            .compactMap { descriptor_Name in
                let link_Path =
                    descriptor_Directory
                    .appendingPathComponent(descriptor_Name).path
                return try? FileManager.default
                    .destinationOfSymbolicLink(atPath: link_Path)
            }
            .compactMap(Self.parseSocketInode)
    }

    /// "socket:[5746]" -> "5746"; other descriptors -> nil.
    static func parseSocketInode(_ link_Target: String) -> String? {
        guard link_Target.hasPrefix("socket:[") else { return nil }
        return String(link_Target.dropFirst(8).dropLast())
    }
}
