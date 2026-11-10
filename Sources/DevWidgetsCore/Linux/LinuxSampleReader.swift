import Foundation

public enum SampleReadError: Error, Equatable {
    case unreadable(path: String)
    case malformed(path: String)
}

/// Reads a `RawSample` from Linux `/proc` and `/sys` trees. The
/// directories are configurable so tests can use recorded fixtures.
public struct LinuxSampleReader: RawSampleReader {
    public let proc_Directory: URL
    public let sys_Directory: URL
    public let volume_Path: String

    public init(
        proc_Directory: URL = URL(fileURLWithPath: "/proc"),
        sys_Directory: URL = URL(fileURLWithPath: "/sys"),
        volume_Path: String = "/"
    ) {
        self.proc_Directory = proc_Directory
        self.sys_Directory = sys_Directory
        self.volume_Path = volume_Path
    }

    public func readSample() throws -> RawSample {
        var sample = RawSample(
            cpu: try readCPU(),
            memory: try readMemory(),
            disk: try readDisk(),
            network: try readNetwork()
        )
        sample.hardware = LinuxHardwareReader(
            sys_Directory: sys_Directory
        ).readHardware()
        sample.processes = LinuxProcessReader(
            proc_Directory: proc_Directory
        ).readProcesses()
        sample.local_Address = NetworkInterfaces.readPrimaryIPv4()
        return sample
    }

    func readCPU() throws -> CPUSample {
        let stat_Text = try readText("stat")
        return try require(
            ProcStatParser.parseCPUSample(from: stat_Text),
            parsed_From: "stat"
        )
    }

    func readMemory() throws -> MemoryUsage {
        let meminfo_Text = try readText("meminfo")
        let pressure_Level = (try? readText("pressure/memory"))
            .flatMap(PressureStallParser.parseLevel)
        return try require(
            MemInfoParser.parseMemory(
                meminfo_Text: meminfo_Text,
                pressure_Level: pressure_Level
            ),
            parsed_From: "meminfo"
        )
    }

    func readDisk() throws -> DiskSample {
        let io_Counters = (try? readText("diskstats"))
            .flatMap(DiskStatsParser.parseCounters)
        return DiskSample(
            space: try FileSystemSpace.capacity(at: volume_Path),
            io_Counters: io_Counters
        )
    }

    func readNetwork() throws -> NetworkCounters {
        let dev_Text = try readText("net/dev")
        return try require(
            NetDevParser.parseCounters(from: dev_Text),
            parsed_From: "net/dev"
        )
    }

    private func readText(_ relative_Path: String) throws -> String {
        let file_URL =
            proc_Directory
            .appendingPathComponent(relative_Path)
        do {
            return try String(contentsOf: file_URL, encoding: .utf8)
        } catch {
            throw SampleReadError.unreadable(path: file_URL.path)
        }
    }

    private func require<Value>(
        _ parsed_Value: Value?,
        parsed_From relative_Path: String
    ) throws -> Value {
        guard let parsed_Value else {
            throw SampleReadError.malformed(path: relative_Path)
        }
        return parsed_Value
    }
}
