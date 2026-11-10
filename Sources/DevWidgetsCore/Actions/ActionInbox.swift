import Foundation

/// Hands actions from the sandboxed widget extension to the menu
/// bar app through the App Group: one file per request, so a
/// widget writing and the app reading never touch the same file.
public struct ActionInbox: Sendable {
    public static let DIRECTORY_NAME = "pending-actions"
    /// A request the app missed for this long is dropped: stopping
    /// a container minutes after the tap would surprise the user.
    public static let MAX_AGE_SECONDS = 60.0

    public let directory_URL: URL

    public init(container_URL: URL) {
        directory_URL = container_URL.appendingPathComponent(
            Self.DIRECTORY_NAME
        )
    }

    public func post(_ action: WidgetAction) throws {
        try FileManager.default.createDirectory(
            at: directory_URL,
            withIntermediateDirectories: true
        )
        let file_URL = directory_URL.appendingPathComponent(
            "\(UUID().uuidString).json"
        )
        let action_Data = try JSONEncoder().encode(action)
        try action_Data.write(to: file_URL, options: .atomic)
    }

    /// Oldest first; removes every file it reads.
    public func drain(at now: Date = Date()) -> [WidgetAction] {
        listRequestFiles()
            .sorted { $0.posted_At < $1.posted_At }
            .compactMap { request_File in
                defer {
                    try? FileManager.default.removeItem(
                        at: request_File.file_URL
                    )
                }
                let age_Seconds = now.timeIntervalSince(
                    request_File.posted_At
                )
                guard age_Seconds <= Self.MAX_AGE_SECONDS else {
                    return nil
                }
                return readAction(request_File.file_URL)
            }
    }

    func listRequestFiles() -> [(file_URL: URL, posted_At: Date)] {
        let file_URLs =
            (try? FileManager.default.contentsOfDirectory(
                at: directory_URL,
                includingPropertiesForKeys: [
                    .contentModificationDateKey
                ]
            )) ?? []
        return file_URLs.filter { $0.pathExtension == "json" }.map {
            let values = try? $0.resourceValues(
                forKeys: [.contentModificationDateKey]
            )
            return (
                $0, values?.contentModificationDate ?? .distantPast
            )
        }
    }

    func readAction(_ file_URL: URL) -> WidgetAction? {
        guard let action_Data = try? Data(contentsOf: file_URL) else {
            return nil
        }
        return try? JSONDecoder().decode(
            WidgetAction.self,
            from: action_Data
        )
    }
}
