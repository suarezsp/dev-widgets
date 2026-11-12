import CGtk
import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// libadwaita preference rows wired to Swift closures.
enum PreferenceRows {
    static func makeSwitchRow(
        _ title: String,
        is_On: Bool,
        changed: @escaping (Bool) -> Void
    ) -> WidgetPointer {
        let row = created(adw_switch_row_new())
        adw_preferences_row_set_title(castPointer(row), title)
        adw_switch_row_set_active(castPointer(row), is_On ? 1 : 0)
        Signals.connectNotify(
            UnsafeMutableRawPointer(row),
            property_Name: "active"
        ) {
            changed(adw_switch_row_get_active(castPointer(row)) != 0)
        }
        return row
    }

    /// A limit: switch in front, the value in a spin button.
    /// Fractions are shown as percent.
    static func makeRuleRow(
        _ rule: AlertRule,
        changed: @escaping (AlertRule) -> Void
    ) -> WidgetPointer {
        let scale = displayScale(rule.metric)
        let row = makeSpinRow(rule, scale: scale)
        let toggle = makeSwitch(is_On: rule.is_Enabled)
        adw_action_row_add_prefix(castPointer(row), toggle)
        let report = {
            var new_Rule = rule
            new_Rule.limit =
                adw_spin_row_get_value(castPointer(row)) / scale
            new_Rule.is_Enabled =
                gtk_switch_get_active(castPointer(toggle)) != 0
            changed(new_Rule)
        }
        watch([(row, "value"), (toggle, "active")], report)
        return row
    }

    /// Percent for fractions, degrees as they are.
    static func displayScale(_ metric: AlertMetric) -> Double {
        metric == .temperature ? 1 : 100
    }

    /// "Above (%)", "Below (%)", "Above (°C)".
    static func describeLimit(_ metric: AlertMetric) -> String {
        let direction =
            metric.alerts_Below_Limit
            ? String(localized: "Below") : String(localized: "Above")
        let unit = metric == .temperature ? "°C" : "%"
        return "\(direction) (\(unit))"
    }

    private static func watch(
        _ properties: [(WidgetPointer, String)],
        _ action: @escaping () -> Void
    ) {
        for (widget, property_Name) in properties {
            Signals.connectNotify(
                UnsafeMutableRawPointer(widget),
                property_Name: property_Name,
                action
            )
        }
    }

    private static func makeSwitch(is_On: Bool) -> WidgetPointer {
        let toggle = created(gtk_switch_new())
        gtk_switch_set_active(castPointer(toggle), is_On ? 1 : 0)
        gtk_widget_set_valign(toggle, GTK_ALIGN_CENTER)
        return toggle
    }

    private static func makeSpinRow(
        _ rule: AlertRule,
        scale: Double
    ) -> WidgetPointer {
        let range = rule.metric.limit_Range
        let row = created(
            adw_spin_row_new_with_range(
                range.lowerBound * scale,
                range.upperBound * scale,
                rule.metric.limit_Step * scale
            )
        )
        adw_preferences_row_set_title(
            castPointer(row),
            AlertMessage.describeName(rule.metric)
        )
        adw_action_row_set_subtitle(
            castPointer(row),
            describeLimit(rule.metric)
        )
        adw_spin_row_set_value(castPointer(row), rule.limit * scale)
        return row
    }

    static func makeActionRow(
        _ title: String,
        subtitle: String,
        suffix: WidgetPointer? = nil
    ) -> WidgetPointer {
        let row = created(adw_action_row_new())
        adw_preferences_row_set_title(castPointer(row), title)
        adw_action_row_set_subtitle(castPointer(row), subtitle)
        if let suffix {
            adw_action_row_add_suffix(castPointer(row), suffix)
        }
        return row
    }

    static func makeEntryRow(
        _ title: String,
        text: String = ""
    )
        -> WidgetPointer
    {
        let row = created(adw_entry_row_new())
        adw_preferences_row_set_title(castPointer(row), title)
        gtk_editable_set_text(castPointer(row), text)
        return row
    }

    static func readText(_ entry_Row: WidgetPointer) -> String {
        String(cString: gtk_editable_get_text(castPointer(entry_Row)))
            .trimmingCharacters(in: .whitespaces)
    }

    static func makeGroup(
        _ title: String,
        description: String? = nil
    ) -> WidgetPointer {
        let group = created(adw_preferences_group_new())
        adw_preferences_group_set_title(castPointer(group), title)
        if let description {
            adw_preferences_group_set_description(
                castPointer(group),
                description
            )
        }
        return group
    }

    static func makePage(_ groups: [WidgetPointer]) -> WidgetPointer {
        let page = created(adw_preferences_page_new())
        for group in groups {
            adw_preferences_page_add(
                castPointer(page),
                castPointer(group)
            )
        }
        return page
    }

    static func add(_ row: WidgetPointer, to group: WidgetPointer) {
        adw_preferences_group_add(castPointer(group), row)
    }
}
