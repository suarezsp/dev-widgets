#if os(macOS)
import Darwin
import DevWidgetsCore

/// Sums the 64-bit byte counters (`if_data64`) of physical
/// interfaces from the `NET_RT_IFLIST2` routing table dump.
/// `getifaddrs` only exposes 32-bit counters that wrap at 4 GiB.
enum DarwinNetworkReader {
    static func readCounters() -> NetworkCounters {
        guard let table = readInterfaceTable() else { return .ZERO }
        return sumPhysicalCounters(in: table)
    }

    static func readInterfaceTable() -> [UInt8]? {
        var request: [Int32] = [
            CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0,
        ]
        let level_Count = UInt32(request.count)
        var table_Size = 0
        guard
            sysctl(&request, level_Count, nil, &table_Size, nil, 0)
                == 0
        else { return nil }
        var table = [UInt8](repeating: 0, count: table_Size)
        guard
            sysctl(&request, level_Count, &table, &table_Size, nil, 0)
                == 0
        else { return nil }
        return Array(table.prefix(table_Size))
    }

    /// Walks the variable-length messages; only `RTM_IFINFO2` ones
    /// carry an `if_msghdr2` with counters.
    static func sumPhysicalCounters(
        in table: [UInt8]
    ) -> NetworkCounters {
        table.withUnsafeBytes { raw_Table in
            var interface_Counters: [NetworkCounters] = []
            var offset = 0
            let message_Size = MemoryLayout<if_msghdr2>.size
            while offset + message_Size <= raw_Table.count {
                let message = raw_Table.loadUnaligned(
                    fromByteOffset: offset,
                    as: if_msghdr2.self
                )
                guard message.ifm_msglen > 0 else { break }
                if Int32(message.ifm_type) == RTM_IFINFO2 {
                    interface_Counters.append(
                        physicalCounters(of: message)
                    )
                }
                offset += Int(message.ifm_msglen)
            }
            return interface_Counters.reduce(.ZERO, +)
        }
    }

    static func physicalCounters(
        of message: if_msghdr2
    ) -> NetworkCounters {
        let name = interfaceName(index: message.ifm_index)
        guard let name, NetworkInterfaces.isPhysical(name) else {
            return .ZERO
        }
        return NetworkCounters(
            received_Bytes: message.ifm_data.ifi_ibytes,
            sent_Bytes: message.ifm_data.ifi_obytes
        )
    }

    static func interfaceName(index: UInt16) -> String? {
        var name_Buffer = [CChar](
            repeating: 0,
            count: Int(IF_NAMESIZE)
        )
        guard if_indextoname(UInt32(index), &name_Buffer) != nil
        else {
            return nil
        }
        return stringFromCBuffer(name_Buffer)
    }
}
#endif
