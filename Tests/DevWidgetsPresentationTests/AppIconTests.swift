import Foundation
import Testing

/// One entry of an asset catalog icon set's Contents.json.
struct IconSetImage: Decodable {
    let filename: String
    let scale: String
    let size: String
}

struct IconSetFile: Decodable {
    let images: [IconSetImage]
}

/// The app's icon set has every macOS size, each PNG at the pixel
/// size its Contents.json entry promises.
struct AppIconTests {
    static let ICON_URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent(
            "../../macOS/App/Assets.xcassets/AppIcon.appiconset"
        )
        .standardizedFileURL

    /// Width from the IHDR chunk: bytes 16 to 19, big endian.
    static func readPixelWidth(_ file_URL: URL) throws -> Int {
        let png_Data = try Data(contentsOf: file_URL)
        try #require(png_Data.count > 24)
        return png_Data[16..<20].reduce(0) { $0 << 8 | Int($1) }
    }

    static func expectedWidth(_ image: IconSetImage) -> Int {
        let points = Int(image.size.prefix { $0 != "x" }) ?? 0
        let scale = Int(image.scale.dropLast()) ?? 0
        return points * scale
    }

    @Test func everyMacSizeHasAPNGOfTheRightWidth() throws {
        let json_Data = try Data(
            contentsOf: Self.ICON_URL.appendingPathComponent(
                "Contents.json"
            )
        )
        let icon_Set = try JSONDecoder().decode(
            IconSetFile.self,
            from: json_Data
        )
        #expect(icon_Set.images.count == 10)
        for image in icon_Set.images {
            let file_URL = Self.ICON_URL.appendingPathComponent(
                image.filename
            )
            let width = try Self.readPixelWidth(file_URL)
            #expect(width == Self.expectedWidth(image))
        }
    }
}
