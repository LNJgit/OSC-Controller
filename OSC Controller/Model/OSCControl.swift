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

    // ✅ NEW
    var alwaysVisible: Bool = true
    var presetIDs: [UUID] = []   // presets that can reveal it
}

struct OSCPresetNode: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var isOn: Bool = false

    // Optional so OutlineGroup knows where leaves end. :contentReference[oaicite:1]{index=1}
    var children: [OSCPresetNode]? = nil
}

struct OSCLayout: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var controls: [OSCControl] = []
    var portString: String = "9000"

    // ✅ NEW: root-level preset tree
    var presetTree: [OSCPresetNode] = []
}



struct OSCAppState: Codable {
    var host: String = "192.168.1.100"
    var portString: String = "9000"
    var layouts: [OSCLayout] = []
    var selectedLayoutID: UUID? = nil
}
