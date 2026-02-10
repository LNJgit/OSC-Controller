import Foundation

@MainActor
final class ControlsStore: ObservableObject {
    @Published var state = OSCAppState()
    let osc = OSCManager()

    init() {
        if state.selectedLayoutID == nil {
            state.selectedLayoutID = state.layouts.first?.id
        }
        syncSettingsToOSC()
    }

    func syncSettingsToOSC() {
        osc.host = state.host
        osc.portString = state.portString
    }


    var currentLayoutIndex: Int? {
        guard let id = state.selectedLayoutID else { return nil }
        return state.layouts.firstIndex(where: { $0.id == id })
    }

    func selectLayout(_ id: UUID) {
        state.selectedLayoutID = id
    }

    func addLayout(named name: String) {
        let new = OSCLayout(name: name)
        state.layouts.append(new)
        state.selectedLayoutID = new.id
        // save()
    }

    func duplicateCurrentLayout() {
        guard let idx = currentLayoutIndex else { return }
        var copy = state.layouts[idx]
        copy.id = UUID()
        copy.name += " Copy"
        copy.controls = copy.controls.map { c in
            var cc = c
            cc.id = UUID()
            return cc
        }
        state.layouts.append(copy)
        state.selectedLayoutID = copy.id
        // save()
    }

    func deleteLayout(_ id: UUID) {
        state.layouts.removeAll { $0.id == id }
        if state.selectedLayoutID == id {
            state.selectedLayoutID = state.layouts.first?.id
        }
        // save()
    }
}

