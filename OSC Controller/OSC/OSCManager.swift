import Foundation
import OSCKit

final class OSCManager: ObservableObject {
    @Published var host: String = "192.168.1.100"
    @Published var portString: String = "9000"

    // OSCKit 2.x: init can be empty; localPort is optional
    private let client = OSCUDPClient()

    private var port: UInt16? { UInt16(portString) }

    func send(_ address: String, _ value: Float) {
        guard let port else {
            print("Invalid port")
            return
        }

        let msg = OSCMessage(address, values: [value])

        do {
            // ✅ `to:` wants the host String
            // ✅ port is a separate argument
            try client.send(.message(msg), to: host, port: port)
        } catch {
            print("OSC send error:", error)
        }
    }

    func trigger(_ address: String) {
        send(address, 1.0)
    }
}
