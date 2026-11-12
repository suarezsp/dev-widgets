import Foundation

#if !canImport(Darwin)
/// What `String(localized:)` gets on Linux: the key Xcode writes
/// in the String Catalog ("%@" for text, "%lld" for whole numbers)
/// and the values, put back after translation.
public struct LinuxLocalizationValue:
    ExpressibleByStringInterpolation,
    Sendable
{
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []

        public init(literalCapacity: Int, interpolationCount: Int) {}

        public mutating func appendLiteral(_ literal: String) {
            key += literal
        }

        public mutating func appendInterpolation(_ value: String) {
            key += "%@"
            arguments.append(value)
        }

        public mutating func appendInterpolation(_ value: Int) {
            key += "%lld"
            arguments.append(String(value))
        }

        public mutating func appendInterpolation(
            _ value: some CustomStringConvertible
        ) {
            appendInterpolation(value.description)
        }
    }

    let key: String
    let arguments: [String]

    public init(stringLiteral value: String) {
        key = value
        arguments = []
    }

    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }
}

extension String {
    /// The text in the user's language (`LANGUAGE`, `LANG`...) from
    /// the same catalog as macOS, or the English key.
    public init(localized value: LinuxLocalizationValue) {
        self = LinuxCatalog.CURRENT.translate(
            value.key,
            arguments: value.arguments
        )
    }

    /// For a key held in a variable, such as a page name.
    public init(localizing key: String) {
        self = LinuxCatalog.CURRENT.translate(key)
    }
}

/// The catalog installed next to the program (`share/devwidgets`
/// beside `bin`), or the checkout's for a run from `.build`.
enum LinuxCatalog {
    static let CHECKOUT_PATH = "macOS/Shared/"
    static let INSTALLED_PATH = "../share/devwidgets/"
    static let MAX_LEVELS = 6
    static let CURRENT = load()

    static func load() -> StringCatalog {
        guard let language = PreferredLanguage.read(),
            language != "en",
            let catalog_URL = locate(),
            let json_Data = try? Data(contentsOf: catalog_URL),
            let catalog = StringCatalog(
                json_Data: json_Data,
                language: language
            )
        else { return .EMPTY }
        return catalog
    }

    static func locate() -> URL? {
        guard
            let bin_URL = Bundle.main.executableURL?
                .resolvingSymlinksInPath().deletingLastPathComponent()
        else { return nil }
        let installed_URL = bin_URL.appendingPathComponent(
            INSTALLED_PATH + StringCatalog.FILE_NAME
        )
        var candidate_URLs = [installed_URL.standardizedFileURL]
        var folder_URL = bin_URL
        for _ in 0..<MAX_LEVELS {
            candidate_URLs.append(
                folder_URL.appendingPathComponent(
                    CHECKOUT_PATH + StringCatalog.FILE_NAME
                )
            )
            folder_URL.deleteLastPathComponent()
        }
        return candidate_URLs.first {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }
}
#endif
