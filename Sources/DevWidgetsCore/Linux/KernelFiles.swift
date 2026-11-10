import Foundation

/// Small, failure-tolerant helpers for the `/proc` and `/sys`
/// trees: a missing or unreadable file is simply absent.
enum KernelFiles {
    static func listNames(in directory: URL) -> [String] {
        let names = try? FileManager.default
            .contentsOfDirectory(atPath: directory.path)
        return (names ?? []).sorted()
    }

    static func readText(
        named file_Name: String,
        in directory: URL
    ) -> String? {
        let file_URL = directory.appendingPathComponent(file_Name)
        return try? String(contentsOf: file_URL, encoding: .utf8)
    }

    /// `/proc/1234`, `/proc/1235`, ...: one directory per process.
    static func listProcessDirectories(
        in proc_Directory: URL
    ) -> [URL] {
        listNames(in: proc_Directory)
            .filter { $0.allSatisfy(\.isNumber) }
            .map { proc_Directory.appendingPathComponent($0) }
    }
}
