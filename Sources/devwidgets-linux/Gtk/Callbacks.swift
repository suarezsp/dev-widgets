import CGtk

// GLib calls C function pointers with a `user_data` pointer. These
// boxes carry a Swift closure through that pointer: GLib keeps one
// retain and drops it through the destroy notify.

final class ActionBox {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    func retainedPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(self).toOpaque()
    }

    static func take(
        _ pointer: UnsafeMutableRawPointer?
    ) -> ActionBox? {
        pointer.map { Unmanaged<ActionBox>.fromOpaque($0) }?
            .takeUnretainedValue()
    }
}

/// The same for callbacks with one value, e.g. a dialog response.
final class ValueBox<Value> {
    let action: (Value) -> Void

    init(_ action: @escaping (Value) -> Void) {
        self.action = action
    }

    func retainedPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(self).toOpaque()
    }

    static func take(
        _ pointer: UnsafeMutableRawPointer?
    ) -> ValueBox<Value>? {
        pointer.map { Unmanaged<ValueBox<Value>>.fromOpaque($0) }?
            .takeUnretainedValue()
    }
}

typealias DestroyNotify =
    @convention(c) (UnsafeMutableRawPointer?)
    -> Void

/// A GDestroyNotify that releases any box.
let RELEASE_BOX: DestroyNotify = { pointer in
    guard let pointer else { return }
    Unmanaged<AnyObject>.fromOpaque(pointer).release()
}

/// A GClosureNotify that releases any box.
let RELEASE_CLOSURE_BOX:
    @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutablePointer<GClosure>?
    )
        -> Void = { pointer, _ in
            guard let pointer else { return }
            Unmanaged<AnyObject>.fromOpaque(pointer).release()
        }

/// GTK types arrive as pointers to different C structs; GObject
/// casts are checked at run time by GLib itself.
func castPointer<Source, Target>(
    _ source: Source,
    to target: Target.Type = Target.self
) -> Target {
    unsafeBitCast(source, to: target)
}

/// GTK constructors never return NULL (GLib aborts when memory
/// runs out), but Swift sees their results as optional.
func created<Pointer>(_ pointer: Pointer?) -> Pointer {
    guard let pointer else { fatalError("GTK returned no object") }
    return pointer
}
