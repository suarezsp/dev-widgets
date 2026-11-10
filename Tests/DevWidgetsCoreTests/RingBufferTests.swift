import Foundation
import Testing
@testable import DevWidgetsCore

struct RingBufferTests {
    @Test func keepsInsertionOrderBeforeFilling() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        #expect(buffer.ordered_Elements == [1, 2])
        #expect(buffer.count == 2)
    }

    @Test func overwritesOldestWhenFull() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 { buffer.append(value) }
        #expect(buffer.ordered_Elements == [3, 4, 5])
        #expect(buffer.count == 3)
    }

    @Test func wrapsAroundManyTimes() {
        var buffer = RingBuffer<Int>(capacity: 2)
        for value in 1...101 { buffer.append(value) }
        #expect(buffer.ordered_Elements == [100, 101])
    }

    @Test func codingKeepsOrderAfterWrapping() throws {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 { buffer.append(value) }
        let data = try JSONEncoder().encode(buffer)
        var decoded = try JSONDecoder()
            .decode(RingBuffer<Int>.self, from: data)
        #expect(decoded == buffer)
        decoded.append(6)
        #expect(decoded.ordered_Elements == [4, 5, 6])
    }

    @Test func zeroCapacityDoesNotDecode() {
        let data = Data(#"{"capacity":0,"elements":[]}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RingBuffer<Int>.self, from: data)
        }
    }
}
