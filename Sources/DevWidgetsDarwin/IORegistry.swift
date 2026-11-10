#if os(macOS)
import DevWidgetsCore
import Foundation
import IOKit

/// Reads the property tables of every IOKit service of one class.
/// Used for GPU utilisation and disk byte counters, which have no
/// higher-level public API.
enum IORegistry {
    static func readProperties(
        of class_Name: String
    ) -> [[String: Any]] {
        var iterator: io_iterator_t = 0
        let matching_Status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(class_Name),
            &iterator
        )
        guard matching_Status == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var all_Properties: [[String: Any]] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let properties = copyProperties(of: service) {
                all_Properties.append(properties)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return all_Properties
    }

    static func copyProperties(
        of service: io_object_t
    ) -> [String: Any]? {
        var properties: Unmanaged<CFMutableDictionary>?
        let copy_Status = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )
        guard copy_Status == KERN_SUCCESS else { return nil }
        return properties?.takeRetainedValue() as? [String: Any]
    }

    /// Reads `table[group][key]` as a number.
    static func readNumber(
        _ key: String,
        in group: String,
        of table: [String: Any]
    ) -> NSNumber? {
        let group_Table = table[group] as? [String: Any]
        return group_Table?[key] as? NSNumber
    }
}

/// GPU busy share from the accelerator's performance statistics.
enum DarwinGPUReader {
    static let SERVICE_CLASS = "IOAccelerator"
    static let STATISTICS_GROUP = "PerformanceStatistics"
    static let UTILIZATION_KEY = "Device Utilization %"

    static func readFraction() -> Double? {
        IORegistry.readProperties(of: SERVICE_CLASS)
            .compactMap {
                IORegistry.readNumber(
                    UTILIZATION_KEY,
                    in: STATISTICS_GROUP,
                    of: $0
                )
            }
            .map { min(1, max(0, $0.doubleValue / 100)) }
            .max()
    }
}

/// Cumulative bytes read and written by every block storage driver.
enum DarwinDiskReader {
    static let SERVICE_CLASS = "IOBlockStorageDriver"
    static let STATISTICS_GROUP = "Statistics"
    static let READ_KEY = "Bytes (Read)"
    static let WRITE_KEY = "Bytes (Write)"

    static func readCounters() -> DiskIOCounters? {
        let drivers = IORegistry.readProperties(of: SERVICE_CLASS)
        guard !drivers.isEmpty else { return nil }
        return drivers.reduce(
            DiskIOCounters(read_Bytes: 0, written_Bytes: 0)
        ) { total, driver in
            DiskIOCounters(
                read_Bytes: total.read_Bytes
                    + readBytes(READ_KEY, of: driver),
                written_Bytes: total.written_Bytes
                    + readBytes(WRITE_KEY, of: driver)
            )
        }
    }

    static func readBytes(
        _ key: String,
        of driver: [String: Any]
    )
        -> UInt64
    {
        let number = IORegistry.readNumber(
            key,
            in: STATISTICS_GROUP,
            of: driver
        )
        return number?.uint64Value ?? 0
    }
}
#endif
