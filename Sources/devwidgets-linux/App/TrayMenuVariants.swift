import CGtk
import DevWidgetsLinuxShell

/// GVariant replies of the dbusmenu methods, built piece by piece
/// because g_variant_new is variadic.
enum TrayMenuVariants {
    /// (u(ia{sv}av)) for GetLayout(parentId, ...): the root with
    /// every item, or the one item asked for.
    static func makeLayoutReply(
        _ arguments: OpaquePointer?
    ) -> OpaquePointer? {
        let item = TrayMenuItem(
            rawValue: VariantReading.readInt32(arguments, 0)
        )
        let node =
            item.map { makeNode($0.rawValue, $0.properties, []) }
            ?? makeNode(
                DBusMenuProtocol.ROOT_ID,
                DBusMenuProtocol.ROOT_PROPERTIES,
                TrayMenuItem.allCases.map {
                    makeNode($0.rawValue, $0.properties, [])
                }
            )
        let children: [OpaquePointer?] = [
            g_variant_new_uint32(DBusMenuProtocol.LAYOUT_REVISION),
            node,
        ]
        return g_variant_new_tuple(children, 2)
    }

    /// (ia{sv}av): an id, its properties and its child nodes.
    static func makeNode(
        _ id: Int32,
        _ properties: [String: TrayPropertyValue],
        _ child_Nodes: [OpaquePointer?]
    ) -> OpaquePointer? {
        let children: [OpaquePointer?] = [
            g_variant_new_int32(id),
            makeDictionary(properties),
            makeArray(
                "v",
                child_Nodes.map { g_variant_new_variant($0) }
            ),
        ]
        return g_variant_new_tuple(children, 3)
    }

    /// (a(ia{sv})) for GetGroupProperties(ids, ...).
    static func makeGroupReply(
        _ arguments: OpaquePointer?
    ) -> OpaquePointer? {
        let items = TrayMenuItem.findRequested(
            VariantReading.readInt32s(arguments, 0)
        )
        let entries = items.map { item in
            let pair: [OpaquePointer?] = [
                g_variant_new_int32(item.rawValue),
                makeDictionary(item.properties),
            ]
            return g_variant_new_tuple(pair, 2)
        }
        return g_variant_new_tuple(
            [makeArray("(ia{sv})", entries)],
            1
        )
    }

    /// (v) for GetProperty(id, name); an empty string when unknown.
    static func makePropertyReply(
        _ arguments: OpaquePointer?
    ) -> OpaquePointer? {
        let item = TrayMenuItem(
            rawValue: VariantReading.readInt32(arguments, 0)
        )
        let value =
            item?.properties[VariantReading.readString(arguments, 1)]
            ?? .text("")
        let wrapped = g_variant_new_variant(TrayVariants.make(value))
        return g_variant_new_tuple([wrapped], 1)
    }

    /// (ai) or (aiai) with nothing to report; nil for Event, which
    /// has no reply values.
    static func makeEmptyListsReply(
        count: Int,
        is_Needed: Bool
    ) -> OpaquePointer? {
        guard is_Needed else { return nil }
        let lists = (0..<count).map { _ in makeArray("i", []) }
        return g_variant_new_tuple(lists, gsize(count))
    }

    static func makeDictionary(
        _ properties: [String: TrayPropertyValue]
    ) -> OpaquePointer? {
        let entries = properties.sorted { $0.key < $1.key }.map {
            g_variant_new_dict_entry(
                g_variant_new_string($0.key),
                g_variant_new_variant(TrayVariants.make($0.value))
            )
        }
        return makeArray("{sv}", entries)
    }

    static func makeArray(
        _ element_Type: String,
        _ elements: [OpaquePointer?]
    ) -> OpaquePointer? {
        let variant_Type = g_variant_type_new(element_Type)
        defer { g_variant_type_free(variant_Type) }
        return g_variant_new_array(
            variant_Type,
            elements,
            gsize(elements.count)
        )
    }
}

/// Reads method arguments out of a GVariant tuple.
enum VariantReading {
    static func readInt32(
        _ tuple: OpaquePointer?,
        _ index: Int
    ) -> Int32 {
        withChild(tuple, index) { g_variant_get_int32($0) } ?? -1
    }

    static func readString(
        _ tuple: OpaquePointer?,
        _ index: Int
    ) -> String {
        withChild(tuple, index) {
            String(cString: g_variant_get_string($0, nil))
        } ?? ""
    }

    static func readInt32s(
        _ tuple: OpaquePointer?,
        _ index: Int
    ) -> [Int32] {
        var values: [Int32] = []
        forEachChild(tuple, index) {
            values.append(g_variant_get_int32($0))
        }
        return values
    }

    /// Visits every element of the array at `index`.
    static func forEachChild(
        _ tuple: OpaquePointer?,
        _ index: Int,
        _ visit: (OpaquePointer?) -> Void
    ) {
        withChild(tuple, index) { array in
            for position in 0..<g_variant_n_children(array) {
                let element = g_variant_get_child_value(
                    array,
                    position
                )
                visit(element)
                g_variant_unref(element)
            }
        }
    }

    @discardableResult
    static func withChild<Value>(
        _ tuple: OpaquePointer?,
        _ index: Int,
        _ read: (OpaquePointer?) -> Value
    ) -> Value? {
        guard let tuple, index < g_variant_n_children(tuple) else {
            return nil
        }
        let child = g_variant_get_child_value(tuple, gsize(index))
        defer { g_variant_unref(child) }
        return read(child)
    }
}
