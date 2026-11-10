import CGtk
import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// What a card asks the app for: a confirmed action or a page.
struct CardHandlers {
    let request: (WidgetAction) -> Void
    let open: (URL) -> Void
}

/// Icon, a bold title over a secondary detail, and an optional
/// trailing button: the rows of the context and server cards.
enum ContextRows {
    static func makeRow(
        _ line: ContextLine,
        icon_Name: String,
        trailing: WidgetPointer? = nil
    ) -> WidgetPointer {
        let row = Widgets.makeBox(vertical: false, spacing: 8)
        let icon = Widgets.makeIcon(icon_Name)
        Widgets.setLevel(icon, line.level)
        let text_Box = Widgets.makeBox(vertical: true, spacing: 1)
        Widgets.expand(text_Box, horizontally: true)
        Widgets.append(
            Widgets.makeLabel(line.title, classes: ["row-title"]),
            Widgets.makeLabel(
                line.detail_Text,
                classes: ["secondary", "caption"]
            ),
            to: text_Box
        )
        Widgets.append(icon, text_Box, to: row)
        if let trailing {
            Widgets.append(trailing, to: row)
        }
        return row
    }

    /// Small caption over a group of rows ("Processes").
    static func makeCaption(_ text: String) -> WidgetPointer {
        Widgets.makeLabel(text, classes: ["section-caption"])
    }

    /// "Updated 10:42": when the shown data was read.
    static func describeTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

/// Process name, CPU share, memory and a quit button. Rows are
/// reused each second, so a click is never lost to a rebuild.
final class ProcessRow {
    static let ROW_COUNT = 3

    let widget = Widgets.makeBox(vertical: false, spacing: 8)
    private let name_Label = Widgets.makeLabel(classes: ["row-title"])
    private let usage_Label = Widgets.makeLabel(
        classes: ["secondary", "caption"]
    )
    private var process: ProcessIdentity?

    init(handlers: CardHandlers) {
        Widgets.expand(name_Label, horizontally: true)
        let quit_Button = Buttons.makeIconButton(
            "window-close-symbolic",
            tooltip_Text: "Quit…"
        ) { [unowned self] in
            guard let process else { return }
            handlers.request(.terminate_Process(process: process))
        }
        Widgets.append(
            name_Label,
            usage_Label,
            quit_Button,
            to: widget
        )
    }

    /// nil hides the row (fewer processes than rows).
    func show(_ usage: ProcessUsage?) {
        process = usage?.identity
        gtk_widget_set_visible(widget, usage == nil ? 0 : 1)
        guard let usage else { return }
        Widgets.setText(name_Label, usage.identity.name)
        Widgets.setText(
            usage_Label,
            MetricFormatting.describeCoreShare(usage.cpu_Fraction)
                + " · "
                + MetricFormatting.describe(
                    bytes: Double(usage.resident_Bytes)
                )
        )
    }
}
