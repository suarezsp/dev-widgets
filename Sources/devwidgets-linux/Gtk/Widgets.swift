import CGtk
import DevWidgetsCore
import DevWidgetsLinuxShell

typealias WidgetPointer = UnsafeMutablePointer<GtkWidget>

/// Thin helpers over the GTK calls the views repeat.
enum Widgets {
    static let LEVEL_CLASSES = ["normal", "elevated", "critical"]

    static func makeBox(
        vertical: Bool,
        spacing: Int32 = 0
    ) -> WidgetPointer {
        gtk_box_new(
            vertical
                ? GTK_ORIENTATION_VERTICAL
                : GTK_ORIENTATION_HORIZONTAL,
            spacing
        )
    }

    static func append(
        _ children: WidgetPointer...,
        to box: WidgetPointer
    ) {
        for child in children {
            gtk_box_append(castPointer(box), child)
        }
    }

    /// Left-aligned, one line, ellipsized at the end.
    static func makeLabel(
        _ text: String = "",
        classes: [String] = []
    ) -> WidgetPointer {
        let label = created(gtk_label_new(text))
        gtk_label_set_xalign(castPointer(label), 0)
        gtk_label_set_ellipsize(
            castPointer(label),
            PANGO_ELLIPSIZE_END
        )
        addClasses(label, classes)
        return label
    }

    static func setText(_ label: WidgetPointer, _ text: String) {
        gtk_label_set_text(castPointer(label), text)
    }

    static func addClasses(
        _ widget: WidgetPointer,
        _ classes: [String]
    ) {
        for class_Name in classes {
            gtk_widget_add_css_class(widget, class_Name)
        }
    }

    /// Green, amber or red text through the level classes.
    static func setLevel(_ widget: WidgetPointer, _ level: LoadLevel)
    {
        for class_Name in LEVEL_CLASSES {
            gtk_widget_remove_css_class(widget, class_Name)
        }
        gtk_widget_add_css_class(widget, LevelColors.className(level))
    }

    static func makeIcon(_ icon_Name: String) -> WidgetPointer {
        let image = created(gtk_image_new_from_icon_name(icon_Name))
        gtk_image_set_pixel_size(castPointer(image), 15)
        return image
    }

    static func expand(_ widget: WidgetPointer, horizontally: Bool) {
        if horizontally {
            gtk_widget_set_hexpand(widget, 1)
        } else {
            gtk_widget_set_vexpand(widget, 1)
        }
    }

    static func fix(_ widget: WidgetPointer, size: WidgetSize) {
        gtk_widget_set_size_request(
            widget,
            Int32(size.width),
            Int32(size.height)
        )
    }

    static func setMargins(_ widget: WidgetPointer, size: Int32) {
        gtk_widget_set_margin_top(widget, size)
        gtk_widget_set_margin_bottom(widget, size)
        gtk_widget_set_margin_start(widget, size)
        gtk_widget_set_margin_end(widget, size)
    }

    /// Empties a box before its rows are rebuilt.
    static func removeChildren(_ box: WidgetPointer) {
        while let child = gtk_widget_get_first_child(box) {
            gtk_box_remove(castPointer(box), child)
        }
    }
}

/// Flat icon buttons and text buttons.
enum Buttons {
    static func makeIconButton(
        _ icon_Name: String,
        tooltip_Text: String,
        action: @escaping () -> Void
    ) -> WidgetPointer {
        let button = created(gtk_button_new_from_icon_name(icon_Name))
        gtk_widget_set_tooltip_text(button, tooltip_Text)
        Widgets.addClasses(
            button,
            ["flat", "circular", "row-action"]
        )
        gtk_widget_set_valign(button, GTK_ALIGN_CENTER)
        Signals.connect(
            UnsafeMutableRawPointer(button),
            "clicked",
            action
        )
        return button
    }

    static func makeTextButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> WidgetPointer {
        let button = created(gtk_button_new_with_label(title))
        gtk_widget_set_valign(button, GTK_ALIGN_CENTER)
        Signals.connect(
            UnsafeMutableRawPointer(button),
            "clicked",
            action
        )
        return button
    }
}
