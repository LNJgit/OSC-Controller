import Foundation
import Combine

/// App-wide store for layouts + global OSC settings.
///
/// Persistent state:
/// - Loads/saves OSCAppState using UserDefaults (JSON-encoded)
/// - Autosaves on any state change (debounced)
@MainActor
final class ControlsStore: ObservableObject {
    @Published var state: OSCAppState
    let osc = OSCManager()

    // MARK: - Persistence

    private static let persistenceKey = "OSCController.appState.v1"
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted state (or fall back to defaults).
        if let loaded = Self.loadState(from: defaults) {
            self.state = loaded
        } else {
            self.state = OSCAppState()
        }

        // ✅ IMPORTANT CHANGE:
        // Do NOT create a default layout when the app opens.
        // If layouts is empty, we keep it empty.

        // Keep selection valid if there ARE layouts:
        if let selected = state.selectedLayoutID,
           state.layouts.contains(where: { $0.id == selected }) == false {
            state.selectedLayoutID = state.layouts.first?.id
        }
        if state.selectedLayoutID == nil, !state.layouts.isEmpty {
            state.selectedLayoutID = state.layouts.first?.id
        }
        if state.layouts.isEmpty {
            state.selectedLayoutID = nil
        }

        syncSettingsToOSC()

        // Autosave any state changes (including changes made via SwiftUI bindings).
        $state
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                Self.saveState(newState, to: self.defaults)
            }
            .store(in: &cancellables)
    }

    private static func loadState(from defaults: UserDefaults) -> OSCAppState? {
        guard let data = defaults.data(forKey: persistenceKey) else { return nil }
        do {
            return try JSONDecoder().decode(OSCAppState.self, from: data)
        } catch {
            // If decoding fails (schema changed), ignore persisted state.
            return nil
        }
    }

    private static func saveState(_ state: OSCAppState, to defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: persistenceKey)
        } catch {
            // Best-effort persistence.
        }
    }

    // MARK: - Global OSC Settings

    func syncSettingsToOSC() {
        osc.host = state.host
    }

    // MARK: - Layout Selection

    var currentLayoutIndex: Int? {
        guard let id = state.selectedLayoutID else { return nil }
        return state.layouts.firstIndex(where: { $0.id == id })
    }

    func selectLayout(_ id: UUID) {
        state.selectedLayoutID = id
    }

    // MARK: - Layout CRUD

    func addLayout(named name: String) {
        let new = OSCLayout(name: name)
        state.layouts.append(new)
        state.selectedLayoutID = new.id
    }

    func deleteLayout(_ id: UUID) {
        state.layouts.removeAll { $0.id == id }

        if state.selectedLayoutID == id {
            // ✅ IMPORTANT CHANGE: allow empty layouts.
            state.selectedLayoutID = state.layouts.first?.id
        }

        if state.layouts.isEmpty {
            state.selectedLayoutID = nil
        }
    }

    // MARK: - Controls

    func removeControl(layoutID: UUID, controlID: UUID) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        state.layouts[lidx].controls.removeAll { $0.id == controlID }
    }

    // MARK: - Presets (Hierarchical Tree)

    func addRootPreset(to layoutID: UUID, name: String) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        let node = OSCPresetNode(name: name, isOn: false, children: nil)
        state.layouts[lidx].presetTree.append(node)
    }

    func addChildPreset(to layoutID: UUID, parentPresetID: UUID, name: String) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        var tree = state.layouts[lidx].presetTree
        let node = OSCPresetNode(name: name, isOn: false, children: [])
        if insertPreset(into: &tree, parentID: parentPresetID, newNode: node) {
            state.layouts[lidx].presetTree = tree
        }
    }

    func deletePreset(layoutID: UUID, presetID: UUID) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }

        var tree = state.layouts[lidx].presetTree
        var deletedIDs = Set<UUID>()
        deletePreset(into: &tree, targetID: presetID, deletedIDs: &deletedIDs)
        state.layouts[lidx].presetTree = tree

        if !deletedIDs.isEmpty {
            for cidx in state.layouts[lidx].controls.indices {
                state.layouts[lidx].controls[cidx].presetIDs.removeAll { deletedIDs.contains($0) }
            }
        }
    }

    func movePreset(layoutID: UUID, presetID: UUID, newParentID: UUID?) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }

        var tree = state.layouts[lidx].presetTree
        guard let extracted = extractPreset(from: &tree, targetID: presetID) else { return }

        if let parentID = newParentID {
            var t = tree
            let inserted = insertExistingPreset(into: &t, parentID: parentID, node: extracted)
            tree = inserted ? t : (tree + [extracted])
        } else {
            tree.append(extracted)
        }

        state.layouts[lidx].presetTree = tree
    }

    // MARK: - Layout Duplication

    func sendPresetToggle(layoutID: UUID, presetID: UUID, presetName: String, isOn: Bool) {
        guard let idx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        let port = state.layouts[idx].portString.isEmpty ? state.portString : state.layouts[idx].portString

        osc.sendPresetToggle(
            "/preset",
            presetID: presetID,
            presetName: presetName,
            isOn: isOn,
            portString: port
        )
    }

    func duplicateCurrentLayout() {
        guard let idx = currentLayoutIndex else { return }
        let original = state.layouts[idx]

        var presetIDMap: [UUID: UUID] = [:]
        let newPresetTree = clonePresetTree(original.presetTree, idMap: &presetIDMap)

        let newControls: [OSCControl] = original.controls.map { c in
            var cc = c
            cc.id = UUID()
            cc.presetIDs = c.presetIDs.compactMap { presetIDMap[$0] }
            return cc
        }

        var copy = original
        copy.id = UUID()
        copy.name += " Copy"
        copy.controls = newControls
        copy.presetTree = newPresetTree

        state.layouts.append(copy)
        state.selectedLayoutID = copy.id
    }

    // MARK: - Sending OSC (per-layout port)

    func send(layoutID: UUID, address: String, value: Float) {
        guard let idx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        let port = state.layouts[idx].portString.isEmpty ? state.portString : state.layouts[idx].portString
        osc.send(address, value, portString: port)
    }

    // MARK: - Private helpers (tree ops)

    private func insertPreset(into nodes: inout [OSCPresetNode], parentID: UUID, newNode: OSCPresetNode) -> Bool {
        for i in nodes.indices {
            if nodes[i].id == parentID {
                if nodes[i].children == nil { nodes[i].children = [] }
                nodes[i].children?.append(newNode)
                return true
            }
            if nodes[i].children != nil {
                var kids = nodes[i].children ?? []
                if insertPreset(into: &kids, parentID: parentID, newNode: newNode) {
                    nodes[i].children = kids
                    return true
                }
            }
        }
        return false
    }

    private func extractPreset(from nodes: inout [OSCPresetNode], targetID: UUID) -> OSCPresetNode? {
        if let idx = nodes.firstIndex(where: { $0.id == targetID }) {
            return nodes.remove(at: idx)
        }
        for i in nodes.indices {
            if nodes[i].children != nil {
                var kids = nodes[i].children ?? []
                if let found = extractPreset(from: &kids, targetID: targetID) {
                    nodes[i].children = kids
                    return found
                }
            }
        }
        return nil
    }

    private func insertExistingPreset(into nodes: inout [OSCPresetNode], parentID: UUID, node: OSCPresetNode) -> Bool {
        for i in nodes.indices {
            if nodes[i].id == parentID {
                if nodes[i].children == nil { nodes[i].children = [] }
                nodes[i].children?.append(node)
                return true
            }
            if nodes[i].children != nil {
                var kids = nodes[i].children ?? []
                if insertExistingPreset(into: &kids, parentID: parentID, node: node) {
                    nodes[i].children = kids
                    return true
                }
            }
        }
        return false
    }

    private func deletePreset(into nodes: inout [OSCPresetNode], targetID: UUID, deletedIDs: inout Set<UUID>) {
        var newNodes: [OSCPresetNode] = []
        newNodes.reserveCapacity(nodes.count)

        for node in nodes {
            if node.id == targetID {
                collectPresetIDs(node, into: &deletedIDs)
                continue
            }

            var kept = node
            if kept.children != nil {
                var kids = kept.children ?? []
                deletePreset(into: &kids, targetID: targetID, deletedIDs: &deletedIDs)
                kept.children = kids
            }
            newNodes.append(kept)
        }

        nodes = newNodes
    }

    private func collectPresetIDs(_ node: OSCPresetNode, into set: inout Set<UUID>) {
        set.insert(node.id)
        if let kids = node.children {
            for k in kids { collectPresetIDs(k, into: &set) }
        }
    }

    private func clonePresetTree(_ nodes: [OSCPresetNode], idMap: inout [UUID: UUID]) -> [OSCPresetNode] {
        nodes.map { node in
            var copy = node
            let newID = UUID()
            idMap[node.id] = newID
            copy.id = newID
            if let kids = node.children {
                copy.children = clonePresetTree(kids, idMap: &idMap)
            }
            return copy
        }
    }
}
