import Testing

import DevWidgetsLinuxShell

struct TrayMenuTests {
    @Test func menuOffersShowHideSettingsAndQuit() {
        let labels = TrayMenuItem.allCases.compactMap {
            $0.properties["label"]
        }
        #expect(
            labels == [
                .text("Show or Hide Dashboard"),
                .text("Preferences…"), .text("Quit DevWidgets"),
            ]
        )
        #expect(
            TrayMenuItem.separator.properties["type"]
                == .text("separator")
        )
    }

    @Test(arguments: [
        (Int32(1), "clicked", TrayMenuItem.toggle_Window),
        (Int32(4), "clicked", TrayMenuItem.quit),
        (Int32(4), "hovered", nil), (Int32(3), "clicked", nil),
        (Int32(0), "clicked", nil), (Int32(9), "clicked", nil),
    ])
    func onlyClicksOnRealItemsAct(
        id: Int32,
        event_ID: String,
        expected_Item: TrayMenuItem?
    ) {
        #expect(
            TrayMenuItem.findClicked(id: id, event_ID: event_ID)
                == expected_Item
        )
    }

    @Test func emptyRequestMeansEveryItem() {
        #expect(TrayMenuItem.findRequested([]).count == 4)
        #expect(TrayMenuItem.findRequested([4, 7]) == [.quit])
    }

    @Test func everyDeclaredMenuPropertyHasAValue() {
        let names = DBusMenuProtocol.INTROSPECTION_XML.components(
            separatedBy: "<property name=\""
        )
        .dropFirst()
        .compactMap { $0.split(separator: "\"").first }
        #expect(names.count == 4)
        for name in names {
            #expect(
                DBusMenuProtocol.value(named: String(name)) != nil
            )
        }
        #expect(
            DBusMenuProtocol.value(named: "Version") == .number(3)
        )
    }
}
