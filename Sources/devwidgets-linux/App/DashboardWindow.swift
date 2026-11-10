import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell
import DevWidgetsPresentation

/// What the header bar buttons ask the app for.
struct WindowHandlers {
    let cards: CardHandlers
    let choose_Project: () -> Void
    let open_Preferences: () -> Void
}

/// The panel: the macOS widget gallery at its real sizes — four
/// small widgets and a medium one, then the three large ones.
final class DashboardWindow {
    static let SMALL_KINDS: [MetricKind] = [
        .cpu, .memory, .disk, .network,
    ]
    static let GAP: Int32 = 16

    let window: WidgetPointer
    private let toast_Overlay = created(adw_toast_overlay_new())
    private let small_Cards = SMALL_KINDS.map {
        SmallMetricCard(kind: $0)
    }
    private let medium_Card = MediumMetricCard(kind: .memory)
    private let dashboard_Card: DashboardCard
    private let context_Card: ContextCard
    private let servers_Card = ServersCard()

    init(
        application: OpaquePointer,
        handlers: WindowHandlers
    ) {
        window = adw_application_window_new(castPointer(application))
        dashboard_Card = DashboardCard(handlers: handlers.cards)
        context_Card = ContextCard(handlers: handlers.cards)
        gtk_window_set_title(castPointer(window), "DevWidgets")
        gtk_window_set_default_size(castPointer(window), 1180, 720)
        Widgets.addClasses(window, ["dashboard"])
        adw_application_window_set_content(
            castPointer(window),
            makeToolbarView(handlers)
        )
    }

    /// Header bar on top; toasts over the scrolling gallery.
    private func makeToolbarView(
        _ handlers: WindowHandlers
    ) -> WidgetPointer {
        let toolbar_View = created(adw_toolbar_view_new())
        adw_toolbar_view_add_top_bar(
            castPointer(toolbar_View),
            Self.makeHeaderBar(handlers)
        )
        adw_toast_overlay_set_child(
            castPointer(toast_Overlay),
            makeScrolledContent()
        )
        adw_toolbar_view_set_content(
            castPointer(toolbar_View),
            toast_Overlay
        )
        return toolbar_View
    }

    private static func makeHeaderBar(
        _ handlers: WindowHandlers
    ) -> WidgetPointer {
        let header_Bar = created(adw_header_bar_new())
        adw_header_bar_pack_start(
            castPointer(header_Bar),
            Buttons.makeIconButton(
                "folder-open-symbolic",
                tooltip_Text: "Choose project folder…",
                action: handlers.choose_Project
            )
        )
        adw_header_bar_pack_end(
            castPointer(header_Bar),
            Buttons.makeIconButton(
                "preferences-system-symbolic",
                tooltip_Text: "Preferences",
                action: handlers.open_Preferences
            )
        )
        return header_Bar
    }

    private func makeScrolledContent() -> WidgetPointer {
        let content = Widgets.makeBox(vertical: true, spacing: 8)
        Widgets.setMargins(content, size: 24)
        Widgets.append(
            makeRow(small_Cards.map(\.widget) + [medium_Card.widget]),
            Self.makeSizeCaption(
                "Small 170 × 170  ·  Medium 364 × 170"
            ),
            makeRow([
                dashboard_Card.widget, context_Card.widget,
                servers_Card.widget,
            ]),
            Self.makeSizeCaption("Large 364 × 382"),
            to: content
        )
        let scrolled_Window = created(gtk_scrolled_window_new())
        gtk_scrolled_window_set_child(
            castPointer(scrolled_Window),
            content
        )
        return scrolled_Window
    }

    private func makeRow(_ cards: [WidgetPointer]) -> WidgetPointer {
        let row = Widgets.makeBox(vertical: false, spacing: Self.GAP)
        gtk_widget_set_halign(row, GTK_ALIGN_CENTER)
        cards.forEach { Widgets.append($0, to: row) }
        return row
    }

    private static func makeSizeCaption(
        _ text: String
    ) -> WidgetPointer {
        let label = Widgets.makeLabel(text, classes: ["size-caption"])
        gtk_label_set_xalign(castPointer(label), 0.5)
        gtk_widget_set_margin_bottom(label, 8)
        return label
    }

    func show(_ snapshot: MetricSnapshot) {
        small_Cards.forEach { $0.update(snapshot.readings) }
        medium_Card.update(snapshot.readings)
        dashboard_Card.update(snapshot)
    }

    func show(_ context: DeveloperContext) {
        context_Card.update(context)
    }

    func show(_ overview: ServerOverview) {
        servers_Card.update(overview)
    }

    func showToast(_ text: String) {
        adw_toast_overlay_add_toast(
            castPointer(toast_Overlay),
            adw_toast_new(text)
        )
    }

    func present() {
        gtk_window_present(castPointer(window))
    }

    /// Shown or hidden from the tray icon.
    func toggle() {
        if gtk_widget_get_visible(window) != 0 {
            gtk_widget_set_visible(window, 0)
        } else {
            present()
        }
    }
}
