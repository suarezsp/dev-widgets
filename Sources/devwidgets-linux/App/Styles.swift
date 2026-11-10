import CGtk

/// The glass look in GTK CSS: translucent cards with a light top
/// edge and a soft shadow over a colourful backdrop. GTK has no
/// backdrop blur, so the cards are more opaque than on macOS.
enum Styles {
    static let CSS = """
        window.dashboard {
          background-color: #dfe6f3;
          background-image:
            radial-gradient(circle farthest-side at 12% 18%,
              alpha(#ffb36b, 0.75), transparent),
            radial-gradient(circle farthest-side at 88% 12%,
              alpha(#7aa7ff, 0.75), transparent),
            radial-gradient(circle farthest-side at 70% 95%,
              alpha(#c58bff, 0.6), transparent);
        }
        window.dashboard headerbar {
          background: transparent; box-shadow: none;
        }
        .widget-card {
          border-radius: 24px; padding: 16px;
          color: rgba(0, 0, 0, 0.88);
          background-color: alpha(white, 0.42);
          background-image: linear-gradient(135deg,
            alpha(white, 0.45), alpha(white, 0.0) 40%,
            alpha(white, 0.0) 70%, alpha(white, 0.16));
          box-shadow: inset 0 1px alpha(white, 0.8),
            inset 0 0 0 1px alpha(white, 0.25),
            0 12px 30px alpha(black, 0.18);
        }
        .widget-card .secondary { color: rgba(60, 60, 67, 0.65); }
        .card-title { font-weight: 600; font-size: 12px; }
        .row-title { font-weight: 600; font-size: 12px; }
        .row-value, .caption { font-size: 11px; }
        .ring-value { font-weight: 700; font-size: 19px; }
        .rate-value { font-size: 15px; }
        .section-caption {
          font-size: 10px; font-weight: 700; opacity: 0.6;
          margin-top: 4px;
        }
        .indented { margin-left: 23px; }
        .size-caption { font-size: 11px; opacity: 0.7; }
        .row-action { min-width: 22px; min-height: 22px; padding: 0; }
        .normal { color: #34c759; }
        .elevated { color: #ff9500; }
        .critical { color: #ff3b30; }
        .widget-card label.normal, .widget-card label.elevated,
        .widget-card label.critical { font-weight: 600; }
        """

    /// Added on top while the dark scheme is on. GTK 4.18 has no
    /// `prefers-color-scheme` media query, so the app switches it.
    static let DARK_CSS = """
        window.dashboard {
          background-color: #141821;
          background-image:
            radial-gradient(circle farthest-side at 12% 18%,
              alpha(#a3501f, 0.6), transparent),
            radial-gradient(circle farthest-side at 88% 12%,
              alpha(#1f4fa3, 0.65), transparent),
            radial-gradient(circle farthest-side at 70% 95%,
              alpha(#5d2a9a, 0.55), transparent);
        }
        .widget-card {
          color: rgba(255, 255, 255, 0.94);
          background-color: alpha(#1c1c22, 0.5);
          background-image: linear-gradient(135deg,
            alpha(white, 0.12), alpha(white, 0.0) 40%,
            alpha(white, 0.0) 70%, alpha(white, 0.05));
          box-shadow: inset 0 1px alpha(white, 0.22),
            inset 0 0 0 1px alpha(white, 0.08),
            0 12px 30px alpha(black, 0.45);
        }
        .widget-card .secondary { color: rgba(235, 235, 245, 0.62); }
        .normal { color: #30d158; }
        .elevated { color: #ff9f0a; }
        .critical { color: #ff453a; }
        """

    static func install() {
        let display = gdk_display_get_default()
        addProvider(CSS, to: display)
        let dark_Provider = makeProvider(DARK_CSS)
        let style_Manager = adw_style_manager_get_default()
        let follow = {
            followScheme(style_Manager, dark_Provider, display)
        }
        follow()
        Signals.connectNotify(
            UnsafeMutableRawPointer(style_Manager),
            property_Name: "dark",
            follow
        )
    }

    private static func followScheme(
        _ style_Manager: OpaquePointer?,
        _ dark_Provider: UnsafeMutablePointer<GtkCssProvider>,
        _ display: OpaquePointer?
    ) {
        guard adw_style_manager_get_dark(style_Manager) != 0 else {
            gtk_style_context_remove_provider_for_display(
                display,
                castPointer(dark_Provider)
            )
            return
        }
        gtk_style_context_add_provider_for_display(
            display,
            castPointer(dark_Provider),
            PRIORITY + 1
        )
    }

    static let PRIORITY = UInt32(
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    private static func makeProvider(
        _ css_Text: String
    ) -> UnsafeMutablePointer<GtkCssProvider> {
        let provider = created(gtk_css_provider_new())
        gtk_css_provider_load_from_string(provider, css_Text)
        return provider
    }

    private static func addProvider(
        _ css_Text: String,
        to display: OpaquePointer?
    ) {
        gtk_style_context_add_provider_for_display(
            display,
            castPointer(makeProvider(css_Text)),
            PRIORITY
        )
    }
}
