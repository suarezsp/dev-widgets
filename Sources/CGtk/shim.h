// GTK 4 and libadwaita for Swift. Swift cannot expand GLib's
// macros, so the few the Linux app needs are inline functions here.
#include <adwaita.h>
#include <gtk/gtk.h>

static inline gulong dw_signal_connect(
    gpointer instance, const char *signal_name, GCallback handler,
    gpointer data, GClosureNotify release) {
    return g_signal_connect_data(
        instance, signal_name, handler, data, release, (GConnectFlags)0);
}

static inline const GVariantType *dw_string_variant_type(void) {
    return G_VARIANT_TYPE_STRING;
}

static inline GType dw_application_window_type(void) {
    return ADW_TYPE_APPLICATION_WINDOW;
}
