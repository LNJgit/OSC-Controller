import Foundation

enum OSCControlType: String, Codable, CaseIterable, Identifiable {
    case slider, button, toggle, xyPad, color, tapTempo,padGrid,choice

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
    
    // XY Pad (0...1 by default, but respects min/max)
    var x: Float = 0
    var y: Float = 0

    // Color (0...1)
    var r: Float = 1
    var g: Float = 1
    var b: Float = 1
    var a: Float = 1

    // ✅ NEW
    var alwaysVisible: Bool = true
    var presetIDs: [UUID] = []   // presets that can reveal it
    
    // ✅ Tap tempo
        // We'll store BPM in `value` for simplicity, but keep a default:
        var tapResetSeconds: Float = 2.0   // if user pauses > this, start fresh

        // ✅ Pad grid
        var gridRows: Int = 4
        var gridCols: Int = 4
        var gridIsMomentary: Bool = true
        var gridStates: [Bool] = []        // used when NOT momentary (toggle mode)

        // ✅ Choice (segmented picker)
        var choiceOptions: [String] = ["A", "B", "C"]
        var choiceIndex: Int = 0
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
