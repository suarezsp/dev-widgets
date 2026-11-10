import AppKit
import DevWidgetsCore

/// Opens the chosen project in the user's editor: the one picked
/// in Settings, else the first installed of a short list, else
/// Finder.
enum ProjectOpener {
    static let EDITOR_KEY = "editorBundleID"
    static let KNOWN_EDITORS: [(name: String, bundle_ID: String)] = [
        ("Cursor", "com.todesktop.230313mzl4w4u92"),
        ("Visual Studio Code", "com.microsoft.VSCode"),
        ("Zed", "dev.zed.Zed"),
        ("Xcode", "com.apple.dt.Xcode"),
    ]

    static func installedEditors() -> [(
        name: String, bundle_ID: String
    )] {
        KNOWN_EDITORS.filter { locate($0.bundle_ID) != nil }
    }

    static func open(_ project_URL: URL?) -> ActionOutcome {
        guard let project_URL else {
            return .refused(reason: "Choose a project first")
        }
        guard let editor_URL = chooseEditor() else {
            NSWorkspace.shared.activateFileViewerSelecting([
                project_URL
            ])
            return .done
        }
        NSWorkspace.shared.open(
            [project_URL],
            withApplicationAt: editor_URL,
            configuration: NSWorkspace.OpenConfiguration()
        )
        return .done
    }

    static func chooseEditor() -> URL? {
        let chosen_ID = UserDefaults.standard.string(
            forKey: EDITOR_KEY
        )
        let candidate_IDs =
            [chosen_ID].compactMap { $0 }
            + KNOWN_EDITORS.map(\.bundle_ID)
        return candidate_IDs.lazy.compactMap(locate).first
    }

    static func locate(_ bundle_ID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundle_ID
        )
    }
}
