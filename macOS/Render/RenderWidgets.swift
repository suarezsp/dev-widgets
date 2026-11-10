import AppKit
import SwiftUI
import WidgetKit

/// Renders every widget with SwiftUI's `ImageRenderer`: the real
/// views and layout on a transparent canvas, in the clear (Liquid
/// Glass), dark and light presentations. The desktop glass is
/// composed afterwards. Usage: devwidgets-render [folder]
@main
struct RenderWidgets {
    static let DEFAULT_FOLDER = "widget-renders"

    @MainActor
    static func main() throws {
        let folder_URL = URL(
            fileURLWithPath: CommandLine.arguments.dropFirst().first
                ?? DEFAULT_FOLDER
        )
        try FileManager.default.createDirectory(
            at: folder_URL,
            withIntermediateDirectories: true
        )
        for job in RenderJob.makeAll() {
            for mode in RenderMode.allCases {
                try render(job, mode: mode, into: folder_URL)
            }
        }
        print("Rendered into \(folder_URL.path)")
    }

    @MainActor
    static func render(
        _ job: RenderJob,
        mode: RenderMode,
        into folder_URL: URL
    ) throws {
        let renderer = ImageRenderer(
            content: WidgetFrame(job: job, mode: mode)
        )
        renderer.scale = WidgetCanvas.SCALE
        guard let image = renderer.cgImage,
            let png_Data = NSBitmapImageRep(cgImage: image)
                .representation(using: .png, properties: [:])
        else { throw RenderError.failed(job.file_Name) }
        let file_Name = "real-\(job.file_Name)-\(mode.rawValue).png"
        try png_Data.write(
            to: folder_URL.appendingPathComponent(file_Name)
        )
    }
}

enum RenderError: Error {
    case failed(String)
}
