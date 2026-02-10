import Foundation

enum OSCControlType: String, Codable, CaseIterable, Identifiable {
    case slider, button, toggle
    var id: String { rawValue }
}

struct OSCControl: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var address: String
    var type: OSCControlType
    var min: Float = 0
    var max: Float = 1
    var value: Float = 0
}

struct OSCLayout: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var controls: [OSCControl] = []
}

struct OSCAppState: Codable {
    var host: String = "192.168.1.100"
    var portString: String = "9000"

    var layouts: [OSCLayout] = [
        OSCLayout(name: "Default")
    ]

    var selectedLayoutID: UUID? = nil
}
