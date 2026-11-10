#if os(macOS)
import DevWidgetsCore

/// Reads a `RawSample` from macOS: Mach host statistics, sysctl,
/// IOKit, libproc and statvfs. Process listing needs the host app
/// to run outside the App Sandbox.
public struct DarwinSampleReader: RawSampleReader {
    /// The writable APFS volume; "/" is the sealed system snapshot.
    public static let DATA_VOLUME_PATH = "/System/Volumes/Data"

    public init() {}

    public func readSample() throws -> RawSample {
        let volume_Space = try FileSystemSpace.capacity(
            at: Self.DATA_VOLUME_PATH
        )
        var sample = RawSample(
            cpu: try DarwinCPUReader.readSample(),
            memory: try DarwinMemoryReader.readUsage(),
            disk: DiskSample(
                space: volume_Space,
                io_Counters: DarwinDiskReader.readCounters()
            ),
            network: DarwinNetworkReader.readCounters()
        )
        sample.hardware = HardwareStatus(
            gpu_Fraction: DarwinGPUReader.readFraction(),
            thermal: DarwinPowerReader.readThermal(),
            battery: DarwinPowerReader.readBattery()
        )
        sample.processes = DarwinProcessReader.readProcesses()
        sample.local_Address = NetworkInterfaces.readPrimaryIPv4()
        return sample
    }
}

public enum DarwinReadError: Error, Equatable {
    case unavailable(call: String)
}
#endif
