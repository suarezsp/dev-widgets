import Testing
@testable import DevWidgetsCore

struct InterfaceTests {
    @Test func virtualInterfacesAreNotPhysical() {
        let virtual_Names = [
            "lo", "docker0", "veth12", "utun3", "wg0",
        ]
        for name in virtual_Names {
            #expect(!NetworkInterfaces.isPhysical(name))
        }
        #expect(NetworkInterfaces.isPhysical("en0"))
        #expect(NetworkInterfaces.isPhysical("eth0"))
    }

    @Test func wiredOrWifiAddressIsPreferred() {
        let addresses = [
            InterfaceAddress(name: "lo", address: "127.0.0.1"),
            InterfaceAddress(name: "docker0", address: "172.17.0.1"),
            InterfaceAddress(name: "ib0", address: "10.0.0.9"),
            InterfaceAddress(name: "en0", address: "192.168.1.20"),
        ]
        let primary = NetworkInterfaces.choosePrimary(addresses)
        #expect(primary == "192.168.1.20")
    }

    @Test func anyPhysicalAddressIsTheFallback() {
        let addresses = [
            InterfaceAddress(name: "lo", address: "127.0.0.1"),
            InterfaceAddress(name: "ib0", address: "10.0.0.9"),
        ]
        #expect(
            NetworkInterfaces.choosePrimary(addresses) == "10.0.0.9"
        )
        #expect(NetworkInterfaces.choosePrimary([]) == nil)
    }

    @Test func thisMachineListsLoopback() {
        let names = NetworkInterfaces.readIPv4Addresses().map(\.name)
        #expect(names.contains("lo") || names.contains("lo0"))
    }
}
