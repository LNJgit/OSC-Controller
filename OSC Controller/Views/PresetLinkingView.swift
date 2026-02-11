import SwiftUI

struct PresetLinkingView: View {
    let presetTree: [OSCPresetNode]
    @Binding var presetIDs: [UUID]

    private func flatten(_ nodes: [OSCPresetNode], prefix: String = "") -> [(UUID, String)] {
        var out: [(UUID, String)] = []
        for n in nodes {
            out.append((n.id, prefix + n.name))
            if let kids = n.children {
                out.append(contentsOf: flatten(kids, prefix: prefix + "  └ "))
            }
        }
        return out
    }

    var body: some View {
        let all = flatten(presetTree)

        ForEach(all, id: \.0) { (id, name) in
            Toggle(name, isOn: Binding(
                get: { presetIDs.contains(id) },
                set: { on in
                    if on {
                        if !presetIDs.contains(id) { presetIDs.append(id) }
                    } else {
                        presetIDs.removeAll { $0 == id }
                    }
                }
            ))
        }
    }
}
