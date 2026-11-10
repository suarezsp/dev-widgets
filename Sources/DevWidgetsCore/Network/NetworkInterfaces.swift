#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

public struct InterfaceAddress: Equatable, Sendable {
    public let name: String
    public let address: String

    public init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

/// Tells physical interfaces from loopback, VPN and container ones,
/// whose traffic would otherwise be counted twice.
public enum NetworkInterfaces {
    public static let VIRTUAL_PREFIXES = [
        "lo", "docker", "veth", "br-", "virbr", "vmnet", "utun",
        "tun",
        "tap", "wg", "bridge", "awdl", "llw", "anpi", "gif", "stf",
    ]
    /// Wired and Wi-Fi names on macOS ("en") and Linux.
    public static let PREFERRED_PREFIXES = ["en", "eth", "wl"]

    public static func isPhysical<Name: StringProtocol>(
        _ name: Name
    ) -> Bool {
        !VIRTUAL_PREFIXES.contains { name.hasPrefix($0) }
    }

    /// The address a developer means by "my local IP".
    public static func choosePrimary(
        _ addresses: [InterfaceAddress]
    ) -> String? {
        let physical = addresses.filter { isPhysical($0.name) }
        let preferred = physical.first { candidate in
            PREFERRED_PREFIXES.contains {
                candidate.name.hasPrefix($0)
            }
        }
        return (preferred ?? physical.first)?.address
    }

    public static func readPrimaryIPv4() -> String? {
        choosePrimary(readIPv4Addresses())
    }

    /// IPv4 addresses of every interface that is up (getifaddrs).
    public static func readIPv4Addresses() -> [InterfaceAddress] {
        var first_Entry: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first_Entry) == 0, let first_Entry else {
            return []
        }
        defer { freeifaddrs(first_Entry) }
        return sequence(first: first_Entry) { $0.pointee.ifa_next }
            .compactMap { ipv4Address(of: $0.pointee) }
    }

    static func ipv4Address(of entry: ifaddrs) -> InterfaceAddress? {
        guard let socket_Address = entry.ifa_addr,
            Int32(socket_Address.pointee.sa_family) == AF_INET,
            entry.ifa_flags & UInt32(IFF_UP) != 0
        else { return nil }
        let internet_Address = socket_Address.withMemoryRebound(
            to: sockaddr_in.self,
            capacity: 1
        ) { $0.pointee.sin_addr }
        return formatIPv4(internet_Address).map {
            InterfaceAddress(
                name: String(cString: entry.ifa_name),
                address: $0
            )
        }
    }

    /// Dotted-quad text, e.g. "192.168.1.20".
    static func formatIPv4(_ internet_Address: in_addr) -> String? {
        var address_Copy = internet_Address
        var text_Buffer = [CChar](
            repeating: 0,
            count: Int(INET_ADDRSTRLEN)
        )
        let buffer_Size = socklen_t(text_Buffer.count)
        guard
            inet_ntop(
                AF_INET,
                &address_Copy,
                &text_Buffer,
                buffer_Size
            )
                != nil
        else { return nil }
        return stringFromCBuffer(text_Buffer)
    }
}

/// Decodes a NUL-terminated C character buffer as UTF-8.
public func stringFromCBuffer(_ buffer: [CChar]) -> String {
    let text_Bytes = buffer.prefix { $0 != 0 }
        .map { UInt8(bitPattern: $0) }
    return String(bytes: text_Bytes, encoding: .utf8) ?? ""
}
