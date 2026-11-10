import CGtk
import DevWidgetsLinuxShell
import Foundation

/// Colour scheme, CSS and the app icon.
enum Appearance {
    static func apply(_ color_Scheme: LaunchOptions.ColorScheme) {
        let scheme: AdwColorScheme
        switch color_Scheme {
        case .system: scheme = ADW_COLOR_SCHEME_DEFAULT
        case .light: scheme = ADW_COLOR_SCHEME_FORCE_LIGHT
        case .dark: scheme = ADW_COLOR_SCHEME_FORCE_DARK
        }
        adw_style_manager_set_color_scheme(
            adw_style_manager_get_default(),
            scheme
        )
        Styles.install()
        gtk_window_set_default_icon_name(LinuxApp.APPLICATION_ID)
    }

    /// When running from the checkout, GTK and the panel learn
    /// where the icon is. Installed, the hicolor theme has it.
    static func installIconPath() -> String? {
        guard let executable_URL = Bundle.main.executableURL,
            let icons_URL = IconLocator.findThemeDirectory(
                executable_URL: executable_URL
            )
        else { return nil }
        gtk_icon_theme_add_search_path(
            gtk_icon_theme_get_for_display(gdk_display_get_default()),
            icons_URL.path
        )
        return icons_URL.path
    }
}
