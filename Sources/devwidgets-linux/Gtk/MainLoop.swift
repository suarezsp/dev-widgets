import CGtk

/// The GTK thread's GLib main loop. Every GTK call happens on it;
/// background work hands its results over with `post`.
enum MainLoop {
    typealias SourceFunction =
        @convention(c) (UnsafeMutableRawPointer?) -> gboolean

    private static let RUN_ONCE: SourceFunction = { data in
        ActionBox.take(data)?.action()
        return 0  // G_SOURCE_REMOVE
    }

    private static let RUN_AGAIN: SourceFunction = { data in
        ActionBox.take(data)?.action()
        return 1  // G_SOURCE_CONTINUE
    }

    /// Thread-safe: queues `action` for the GTK thread.
    static func post(_ action: @escaping () -> Void) {
        g_idle_add_full(
            G_PRIORITY_DEFAULT_IDLE,
            RUN_ONCE,
            ActionBox(action).retainedPointer(),
            RELEASE_BOX
        )
    }

    /// Runs `action` on the GTK thread every `milliseconds`.
    static func repeatEvery(
        milliseconds: UInt32,
        _ action: @escaping () -> Void
    ) {
        g_timeout_add_full(
            G_PRIORITY_DEFAULT,
            milliseconds,
            RUN_AGAIN,
            ActionBox(action).retainedPointer(),
            RELEASE_BOX
        )
    }
}
