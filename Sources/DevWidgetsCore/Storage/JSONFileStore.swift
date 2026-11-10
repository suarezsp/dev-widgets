import Foundation

/// Persists one value as a JSON file in a shared directory (the App
/// Group container on macOS), so widgets can read what the app saw.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let file_URL: URL

    public init(directory: URL, file_Name: String) {
        file_URL = directory.appendingPathComponent(file_Name)
    }

    public func save(_ value: Value) throws {
        let encoded_Data = try JSONEncoder().encode(value)
        try encoded_Data.write(to: file_URL, options: .atomic)
    }

    public func remove() {
        try? FileManager.default.removeItem(at: file_URL)
    }

    /// Returns nil when nothing has been saved yet.
    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: file_URL.path)
        else { return nil }
        let stored_Data = try Data(contentsOf: file_URL)
        return try JSONDecoder().decode(Value.self, from: stored_Data)
    }
}

public typealias SnapshotStore = JSONFileStore<MetricSnapshot>

extension JSONFileStore where Value == MetricSnapshot {
    public static let FILE_NAME = "latest-snapshot.json"

    public init(directory: URL) {
        self.init(directory: directory, file_Name: Self.FILE_NAME)
    }
}
