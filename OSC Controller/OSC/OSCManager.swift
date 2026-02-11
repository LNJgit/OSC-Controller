import Foundation
import OSCKit

final class OSCManager: ObservableObject {
    @Published var host: String = "192.168.1.100"

    private let client = OSCUDPClient()

    func send(_ address: String, _ value: Float, portString: String) {
        guard let port = UInt16(portString) else {
            print("Invalid port:", portString)
            return
        }

        let msg = OSCMessage(address, values: [value])

        do {
            try client.send(.message(msg), to: host, port: port)
        } catch {
            print("OSC send error:", error)
        }
    }
    
    func sendPresetToggle(
        _ address: String,
        presetID: UUID,
        presetName: String,
        isOn: Bool,
        portString: String
    ) {
        guard let port = UInt16(portString) else {
            print("Invalid port:", portString)
            return
        }

        // OSC message with multiple args:
        // [String id, String name, Int32 state]
        let msg = OSCMessage(
            address,
            values: [
                presetID.uuidString,
                presetName,
                Int32(isOn ? 1 : 0)
            ]
        )

        do {
            try client.send(.message(msg), to: host, port: port)
        } catch {
            print("OSC send error:", error)
        }
    }



    func trigger(_ address: String, portString: String) {
        send(address, 1.0, portString: portString)
    }
    
    
}
