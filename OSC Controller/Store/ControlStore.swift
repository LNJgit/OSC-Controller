import Foundation
import Combine

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
        // save()
    }

    func deleteLayout(_ id: UUID) {
        state.layouts.removeAll { $0.id == id }
        if state.selectedLayoutID == id {
            state.selectedLayoutID = state.layouts.first?.id
        }
        // save()
    }

    // MARK: - Controls

    func removeControl(layoutID: UUID, controlID: UUID) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        state.layouts[lidx].controls.removeAll { $0.id == controlID }
        // No preset cleanup needed here because presets don't store control IDs anymore.
    }

    // MARK: - Presets (Hierarchical Tree)

    /// Add a preset at the root of the layout preset tree.
    func addRootPreset(to layoutID: UUID, name: String) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        let node = OSCPresetNode(name: name, isOn: false, children: nil)
        state.layouts[lidx].presetTree.append(node)
    }

    /// Add a preset as a child of an existing preset.
    func addChildPreset(to layoutID: UUID, parentPresetID: UUID, name: String) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        var tree = state.layouts[lidx].presetTree
        let node = OSCPresetNode(name: name, isOn: false, children: [])
        if insertPreset(into: &tree, parentID: parentPresetID, newNode: node) {
            state.layouts[lidx].presetTree = tree
        }
    }

    /// Delete a preset anywhere in the tree (removes its entire subtree).
    /// Also removes deleted preset IDs from any controls that referenced them.
    func deletePreset(layoutID: UUID, presetID: UUID) {
        guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }

        var tree = state.layouts[lidx].presetTree
        var deletedIDs = Set<UUID>()
        deletePreset(into: &tree, targetID: presetID, deletedIDs: &deletedIDs)

        // Apply updated tree
        state.layouts[lidx].presetTree = tree

        // Remove deleted IDs from controls' presetIDs
        if !deletedIDs.isEmpty {
            for cidx in state.layouts[lidx].controls.indices {
                state.layouts[lidx].controls[cidx].presetIDs.removeAll { deletedIDs.contains($0) }
            }
        }
    }

    // MARK: - Layout Duplication (deep copy + remap IDs)

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

        // 1) Duplicate preset tree with new IDs and build presetID map
        var presetIDMap: [UUID: UUID] = [:]
        let newPresetTree = clonePresetTree(original.presetTree, idMap: &presetIDMap)

        // 2) Duplicate controls with new IDs and remap their presetIDs using presetIDMap
        var controlIDMap: [UUID: UUID] = [:]
        let newControls: [OSCControl] = original.controls.map { c in
            var cc = c
            let newID = UUID()
            controlIDMap[c.id] = newID
            cc.id = newID

            // Remap preset links
            cc.presetIDs = c.presetIDs.compactMap { presetIDMap[$0] }

            return cc
        }

        // 3) Assemble layout copy
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
    
    func movePreset(layoutID: UUID, presetID: UUID, newParentID: UUID?) {
            guard let lidx = state.layouts.firstIndex(where: { $0.id == layoutID }) else { return }

            var tree = state.layouts[lidx].presetTree

            // 1) Extract the node (removes it from wherever it currently is)
            guard let extracted = extractPreset(from: &tree, targetID: presetID) else { return }

            // 2) Insert as root or under new parent
            if let parentID = newParentID {
                var t = tree
                let inserted = insertExistingPreset(into: &t, parentID: parentID, node: extracted)
                if inserted {
                    tree = t
                } else {
                    // parent not found -> fall back to root
                    tree.append(extracted)
                }
            } else {
                tree.append(extracted)
            }

            state.layouts[lidx].presetTree = tree
        }
    
    private func extractPreset(from nodes: inout [OSCPresetNode], targetID: UUID) -> OSCPresetNode? {
            // Look at this level
            if let idx = nodes.firstIndex(where: { $0.id == targetID }) {
                return nodes.remove(at: idx)
            }

            // Recurse into children
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
        // Walk and remove at this level
        var newNodes: [OSCPresetNode] = []
        newNodes.reserveCapacity(nodes.count)

        for node in nodes {
            if node.id == targetID {
                // Collect all IDs in subtree
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
    
    private func oscSafeSegment(_ s: String) -> String {
        let noDiacritics = s.folding(options: .diacriticInsensitive, locale: .current)
        let spaced = noDiacritics.replacingOccurrences(of: " ", with: "_")

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let cleanedScalars = spaced.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(cleanedScalars))

        return cleaned.isEmpty ? "preset" : cleaned
    }
}
