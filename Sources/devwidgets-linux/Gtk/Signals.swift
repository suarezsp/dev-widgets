import CGtk

/// Swift closures on GObject signals.
enum Signals {
    private static let PLAIN_HANDLER:
        @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
        )
            -> Void = { _, data in ActionBox.take(data)?.action() }

    private static let NOTIFY_HANDLER:
        @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutableRawPointer?,
            UnsafeMutableRawPointer?
        ) -> Void = { _, _, data in ActionBox.take(data)?.action() }

    private static let STRING_HANDLER:
        @convention(c) (
            UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
            UnsafeMutableRawPointer?
        ) -> Void = { _, text, data in
            ValueBox<String>.take(data)?.action(
                text.map { String(cString: $0) } ?? ""
            )
        }

    private static let VARIANT_HANDLER:
        @convention(c) (
            UnsafeMutableRawPointer?, OpaquePointer?,
            UnsafeMutableRawPointer?
        ) -> Void = { _, variant, data in
            ValueBox<OpaquePointer?>.take(data)?.action(variant)
        }

    /// Signals whose handler takes only the instance: "clicked",
    /// "activate", "close-request" (whose return is ignored, so the
    /// window stays open: see `Windows.hideOnClose`).
    static func connect(
        _ instance: UnsafeMutableRawPointer?,
        _ signal_Name: String,
        _ action: @escaping () -> Void
    ) {
        dw_signal_connect(
            instance,
            signal_Name,
            unsafeBitCast(PLAIN_HANDLER, to: GCallback.self),
            ActionBox(action).retainedPointer(),
            RELEASE_CLOSURE_BOX
        )
    }

    /// "notify::<property>": a property changed.
    static func connectNotify(
        _ instance: UnsafeMutableRawPointer?,
        property_Name: String,
        _ action: @escaping () -> Void
    ) {
        dw_signal_connect(
            instance,
            "notify::\(property_Name)",
            unsafeBitCast(NOTIFY_HANDLER, to: GCallback.self),
            ActionBox(action).retainedPointer(),
            RELEASE_CLOSURE_BOX
        )
    }

    /// Signals with one string argument, e.g. AdwAlertDialog's
    /// "response".
    static func connectString(
        _ instance: UnsafeMutableRawPointer?,
        _ signal_Name: String,
        _ action: @escaping (String) -> Void
    ) {
        dw_signal_connect(
            instance,
            signal_Name,
            unsafeBitCast(STRING_HANDLER, to: GCallback.self),
            ValueBox(action).retainedPointer(),
            RELEASE_CLOSURE_BOX
        )
    }

    /// GSimpleAction's "activate" with its GVariant parameter.
    static func connectVariant(
        _ instance: UnsafeMutableRawPointer?,
        _ signal_Name: String,
        _ action: @escaping (OpaquePointer?) -> Void
    ) {
        dw_signal_connect(
            instance,
            signal_Name,
            unsafeBitCast(VARIANT_HANDLER, to: GCallback.self),
            ValueBox(action).retainedPointer(),
            RELEASE_CLOSURE_BOX
        )
    }
}
