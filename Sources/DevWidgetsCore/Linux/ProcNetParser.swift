#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A listening socket from `/proc/net/tcp` or `/proc/net/tcp6`.
struct SocketEntry: Equatable {
    let port: UInt16
    let address: String
    let inode: String
}

/// Parses `/proc/net/tcp{,6}`. Addresses are hex in kernel byte
/// order: "0100007F:1F90" is 127.0.0.1:8080.
enum ProcNetParser {
    static let LISTEN_STATE = "0A"
    static let LOCAL_ADDRESS_INDEX = 1
    static let STATE_INDEX = 3
    static let INODE_INDEX = 9

    static func parseListening(table_Text: String) -> [SocketEntry] {
        table_Text.split(whereSeparator: \.isNewline).dropFirst()
            .compactMap { parseLine($0) }
    }

    static func parseLine(_ line: Substring) -> SocketEntry? {
        let fields = line.split(separator: " ")
        guard fields.count > INODE_INDEX,
            fields[STATE_INDEX] == LISTEN_STATE
        else { return nil }
        let local_Parts = fields[LOCAL_ADDRESS_INDEX].split(
            separator: ":"
        )
        guard local_Parts.count == 2,
            let port = UInt16(local_Parts[1], radix: 16),
            let address = formatAddress(hex_Text: local_Parts[0])
        else { return nil }
        return SocketEntry(
            port: port,
            address: address,
            inode: String(fields[INODE_INDEX])
        )
    }

    /// 8 hex digits for IPv4, 32 for IPv6, in 32-bit words of host
    /// (little-endian) byte order.
    static func formatAddress(hex_Text: Substring) -> String? {
        let address_Bytes = parseWordBytes(hex_Text)
        guard address_Bytes.count == 4 || address_Bytes.count == 16
        else { return nil }
        if address_Bytes.allSatisfy({ $0 == 0 }) {
            return ListeningPort.ANY_ADDRESS
        }
        let family = address_Bytes.count == 4 ? AF_INET : AF_INET6
        return formatBytes(address_Bytes, family: family)
    }

    static func parseWordBytes(_ hex_Text: Substring) -> [UInt8] {
        let digits = Array(hex_Text)
        guard digits.count.isMultiple(of: 8) else { return [] }
        let word_Starts = stride(from: 0, to: digits.count, by: 8)
        return word_Starts.flatMap { word_Start in
            stride(from: word_Start + 6, through: word_Start, by: -2)
                .compactMap {
                    UInt8(String(digits[$0...$0 + 1]), radix: 16)
                }
        }
    }

    static func formatBytes(
        _ address_Bytes: [UInt8],
        family: Int32
    ) -> String? {
        var text_Buffer = [CChar](
            repeating: 0,
            count: Int(INET6_ADDRSTRLEN)
        )
        let buffer_Size = socklen_t(text_Buffer.count)
        let formatted = address_Bytes.withUnsafeBytes {
            inet_ntop(
                family,
                $0.baseAddress,
                &text_Buffer,
                buffer_Size
            )
        }
        return formatted == nil ? nil : stringFromCBuffer(text_Buffer)
    }
}
