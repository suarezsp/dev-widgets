// swift-tools-version: 6.2
import Foundation
import PackageDescription

// The Darwin target talks to Mach C APIs whose globals are not
// concurrency-annotated, so it stays in Swift 5 language mode.
let DARWIN_SETTINGS: [SwiftSetting] = [.swiftLanguageMode(.v5)]

// macOS/Shared files that use only DevWidgetsCore and Foundation.
// The Xcode project compiles them into the app and the widgets;
// this target compiles and tests the same files on Linux.
let PORTABLE_PRESENTATION_FILES = [
    "Shared/ContextPresentation.swift",
    "Shared/GitHubPresentation.swift",
    "Shared/HardwarePresentation.swift",
    "Shared/MetricKind.swift",
    "Shared/MetricPresentation.swift",
    "Shared/PreviewContext.swift",
    "Shared/PreviewData.swift",
    "Shared/PreviewServers.swift",
    "Shared/ReviewQueuePresentation.swift",
    "Shared/ServerPresentation.swift",
    "Shared/WidgetActionStyle.swift",
    "App/AlertSettingsStore.swift",
    "App/LoginItemOffer.swift",
]

// The rest of macOS/ is for Xcode only (SwiftUI, WidgetKit). The
// folders are listed, so new files there need no manifest change.
let XCODE_ONLY_PATHS = [
    "App/Views", "Widgets", "Render", "project.yml",
]
let PRESENTATION_EXCLUDED =
    XCODE_ONLY_PATHS
    + ["App", "Shared"].flatMap { folder in
        ((try? FileManager.default.contentsOfDirectory(
            atPath: Context.packageDirectory + "/macOS/" + folder
        )) ?? [])
        .filter { $0.hasSuffix(".swift") }
        .map { folder + "/" + $0 }
        .filter { !PORTABLE_PRESENTATION_FILES.contains($0) }
    }

// The Linux app needs the GTK 4 and libadwaita headers
// (libgtk-4-dev, libadwaita-1-dev). Without them, on macOS or on a
// bare Linux CI image, everything else still builds and tests.
let HAS_GTK = FileManager.default.fileExists(
    atPath: "/usr/include/libadwaita-1/adwaita.h"
)

// Swift 5 mode for the GTK target: GTK's C API is not
// concurrency-annotated and all its calls stay on the GTK thread.
let GTK_SETTINGS: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let GTK_TARGETS: [Target] = [
    .systemLibrary(
        name: "CGtk",
        pkgConfig: "gtk4 libadwaita-1",
        providers: [.apt(["libgtk-4-dev", "libadwaita-1-dev"])]
    ),
    .executableTarget(
        name: "devwidgets-linux",
        dependencies: [
            "CGtk", "DevWidgetsCore", "DevWidgetsPresentation",
            "DevWidgetsLinuxShell",
        ],
        swiftSettings: GTK_SETTINGS
    ),
]

let GTK_PRODUCTS: [Product] = [
    .executable(
        name: "devwidgets-linux",
        targets: ["devwidgets-linux"]
    )
]

let package = Package(
    name: "DevWidgets",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DevWidgetsCore", targets: ["DevWidgetsCore"]),
        .library(
            name: "DevWidgetsDarwin",
            targets: ["DevWidgetsDarwin"]
        ),
        .executable(
            name: "devwidgets-probe",
            targets: ["devwidgets-probe"]
        ),
    ] + (HAS_GTK ? GTK_PRODUCTS : []),
    targets: [
        .target(name: "DevWidgetsCore"),
        .target(
            name: "DevWidgetsDarwin",
            dependencies: ["DevWidgetsCore"],
            swiftSettings: DARWIN_SETTINGS
        ),
        .executableTarget(
            name: "devwidgets-probe",
            dependencies: ["DevWidgetsCore", "DevWidgetsDarwin"]
        ),
        .target(
            name: "DevWidgetsPresentation",
            dependencies: ["DevWidgetsCore"],
            path: "macOS",
            exclude: PRESENTATION_EXCLUDED,
            sources: PORTABLE_PRESENTATION_FILES
        ),
        .testTarget(
            name: "DevWidgetsCoreTests",
            dependencies: ["DevWidgetsCore"]
        ),
        // Reads the real Mac; empty elsewhere.
        .testTarget(
            name: "DevWidgetsDarwinTests",
            dependencies: ["DevWidgetsCore", "DevWidgetsDarwin"],
            swiftSettings: DARWIN_SETTINGS
        ),
        .testTarget(
            name: "DevWidgetsPresentationTests",
            dependencies: [
                "DevWidgetsCore", "DevWidgetsPresentation",
            ]
        ),
        // Linux shell logic without GTK: settings, notifications,
        // tray texts, dashboard layout. Builds everywhere.
        .target(
            name: "DevWidgetsLinuxShell",
            dependencies: [
                "DevWidgetsCore", "DevWidgetsPresentation",
            ]
        ),
        .testTarget(
            name: "DevWidgetsLinuxShellTests",
            dependencies: ["DevWidgetsCore", "DevWidgetsLinuxShell"]
        ),
    ] + (HAS_GTK ? GTK_TARGETS : [])
)
