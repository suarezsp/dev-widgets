import Testing
@testable import DevWidgetsCore

struct NetworkTests {
    @Test func netDevSumsOnlyPhysicalInterfaces() throws {
        let dev_Text = try Fixtures.text("net/dev")
        let counters = try #require(
            NetDevParser.parseCounters(from: dev_Text)
        )
        #expect(
            counters.received_Bytes == 1_500_000 + 123_456_789_012
        )
        #expect(counters.sent_Bytes == 500_000 + 1_000_000)
    }

    @Test func counterTouchingTheColonIsParsed() throws {
        let line: Substring =
            " wlan0:42 0 0 0 0 0 0 0 7 0 0 0 0 0 0 0"
        let parsed_Line = try #require(
            NetDevParser.parseInterfaceLine(line)
        )
        #expect(parsed_Line.name == "wlan0")
        #expect(parsed_Line.counters.received_Bytes == 42)
        #expect(parsed_Line.counters.sent_Bytes == 7)
    }

    @Test func textWithoutInterfacesIsNil() {
        let header_Text = "Inter-|   Receive\n face |bytes\n"
        #expect(NetDevParser.parseCounters(from: header_Text) == nil)
    }

    @Test func loopbackOnlyMeansZeroTraffic() {
        let loopback_Text = "lo: 5 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0"
        let counters = NetDevParser.parseCounters(from: loopback_Text)
        #expect(counters == .ZERO)
    }

    @Test func throughputIsBytesPerSecond() {
        let previous = NetworkCounters(
            received_Bytes: 0,
            sent_Bytes: 10
        )
        let current = NetworkCounters(
            received_Bytes: 4_000,
            sent_Bytes: 30
        )
        let throughput = NetworkThroughput(
            from: previous,
            to: current,
            elapsed_Seconds: 4
        )
        #expect(throughput.download_Bytes_Per_Second == 1_000)
        #expect(throughput.upload_Bytes_Per_Second == 5)
    }

    @Test func counterResetYieldsZeroRate() {
        let rate = bytesPerSecond(
            from: 9_000,
            to: 10,
            elapsed_Seconds: 1
        )
        #expect(rate == 0)
    }

    @Test func zeroElapsedTimeYieldsZeroRate() {
        #expect(
            bytesPerSecond(from: 0, to: 10, elapsed_Seconds: 0) == 0
        )
    }
}
