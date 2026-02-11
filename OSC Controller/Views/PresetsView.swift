import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    let layoutID: UUID

    @State private var newRootName: String = ""

    // Sheets
    @State private var editingPresetID: UUID? = nil
    @State private var addingChildToPresetID: UUID? = nil
    @State private var movingPresetID: UUID? = nil

    @State private var newChildName: String = ""
    @State private var chosenParentID: UUID? = nil
    
    @State private var showAddChildSheet = false
    @State private var addChildParentID: UUID? = nil


    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    var body: some View {
        NavigationStack {
            Form {
                if let lidx = layoutIndex {
                    Section("Create root preset") {
                        TextField("Preset name", text: $newRootName)
                        Button("Create") {
                            let name = newRootName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            store.addRootPreset(to: layoutID, name: name)
                            newRootName = ""
                        }
                        Button("Add child preset…") {
                            showAddChildSheet = true
                        }
                        .disabled(store.state.layouts[lidx].presetTree.isEmpty)

                    }

                    Section("Preset tree") {
                        if store.state.layouts[lidx].presetTree.isEmpty {
                            Text("No presets yet. Create one above.")
                                .foregroundStyle(.secondary)
                        } else {
                            OutlineGroup($store.state.layouts[lidx].presetTree, children: \.children) { $node in
                                Toggle(node.name, isOn: $node.isOn)
                                    .contextMenu {
                                        Button {
                                            addingChildToPresetID = node.id
                                            newChildName = ""
                                        } label: {
                                            Label("Add child preset", systemImage: "plus")
                                        }

                                        Button {
                                            movingPresetID = node.id
                                            chosenParentID = nil
                                        } label: {
                                            Label("Move to parent…", systemImage: "arrow.turn.down.right")
                                        }

                                        Button {
                                            editingPresetID = node.id
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Divider()

                                        Button(role: .destructive) {
                                            store.deletePreset(layoutID: layoutID, presetID: node.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    Text("Layout not found.")
                }
            }
            .navigationTitle("Presets")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { editingPresetID.map { UUIDBox(id: $0) } },
                set: { editingPresetID = $0?.id }
            )) { box in
                PresetNodeEditorSheet(layoutID: layoutID, presetID: box.id)
                    .environmentObject(store)
            }
            .sheet(item: Binding(
                get: { addingChildToPresetID.map { UUIDBox(id: $0) } },
                set: { addingChildToPresetID = $0?.id }
            )) { box in
                AddChildPresetSheet(
                    layoutID: layoutID,
                    parentPresetID: box.id,
                    childName: $newChildName
                )
                .environmentObject(store)
            }
            .sheet(isPresented: $showAddChildSheet) {
                AddChildByPickerSheet(
                    layoutID: layoutID,
                    parentID: $addChildParentID
                )
                .environmentObject(store)
            }
            .sheet(item: Binding(
                get: { movingPresetID.map { UUIDBox(id: $0) } },
                set: { movingPresetID = $0?.id }
            )) { box in
                ParentPickerSheet(
                    layoutID: layoutID,
                    movingPresetID: box.id,
                    chosenParentID: $chosenParentID
                )
                .environmentObject(store)
            }
        }
    }
}

// MARK: - Sheets

private struct AddChildPresetSheet: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    let layoutID: UUID
    let parentPresetID: UUID
    @Binding var childName: String

    var body: some View {
        NavigationStack {
            Form {
                Section("New child preset") {
                    TextField("Child name", text: $childName)

                    Button("Create") {
                        let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        store.addChildPreset(to: layoutID, parentPresetID: parentPresetID, name: name)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Add Child")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct ParentPickerSheet: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    let layoutID: UUID
    let movingPresetID: UUID
    @Binding var chosenParentID: UUID?

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    private func flatten(_ nodes: [OSCPresetNode], prefix: String = "") -> [(UUID, String)] {
        var out: [(UUID, String)] = []
        for n in nodes {
            // prevent choosing itself as parent
            if n.id != movingPresetID {
                out.append((n.id, prefix + n.name))
            }
            if let kids = n.children {
                out.append(contentsOf: flatten(kids, prefix: prefix + "  └ "))
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            Form {
                if let lidx = layoutIndex {
                    let options = flatten(store.state.layouts[lidx].presetTree)

                    Section("New parent") {
                        Picker("Parent", selection: $chosenParentID) {
                            Text("No parent (make root)").tag(UUID?.none)
                            ForEach(options, id: \.0) { (id, name) in
                                Text(name).tag(Optional(id))
                            }
                        }
                    }

                    Section {
                        Button("Move") {
                            store.movePreset(layoutID: layoutID, presetID: movingPresetID, newParentID: chosenParentID)
                            dismiss()
                        }
                    }
                } else {
                    Text("Layout not found.")
                }
            }
            .navigationTitle("Move Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct PresetNodeEditorSheet: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    let layoutID: UUID
    let presetID: UUID

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    var body: some View {
        NavigationStack {
            Form {
                if let lidx = layoutIndex, let binding = presetBinding(lidx: lidx, presetID: presetID) {
                    Section("Preset") {
                        TextField("Name", text: binding.name)
                        Toggle("Enabled", isOn: binding.isOn)
                    }

                    Section {
                        Button(role: .destructive) {
                            store.deletePreset(layoutID: layoutID, presetID: presetID)
                            dismiss()
                        } label: {
                            Label("Delete preset", systemImage: "trash")
                        }
                    }
                } else {
                    Text("Preset not found.")
                }
            }
            .navigationTitle("Edit Preset")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Binding lookup by presetID (edit deep nodes)

    private func presetBinding(lidx: Int, presetID: UUID) -> (name: Binding<String>, isOn: Binding<Bool>)? {
        guard let path = findPath(in: store.state.layouts[lidx].presetTree, target: presetID) else { return nil }

        let nodeBinding = Binding<OSCPresetNode>(
            get: { getNode(at: path, from: store.state.layouts[lidx].presetTree) },
            set: { newNode in
                var tree = store.state.layouts[lidx].presetTree
                setNode(at: path, in: &tree, to: newNode)
                store.state.layouts[lidx].presetTree = tree
            }
        )

        return (name: nodeBinding.name, isOn: nodeBinding.isOn)
    }

    private func findPath(in nodes: [OSCPresetNode], target: UUID) -> [Int]? {
        for i in nodes.indices {
            if nodes[i].id == target { return [i] }
            if let kids = nodes[i].children, let sub = findPath(in: kids, target: target) {
                return [i] + sub
            }
        }
        return nil
    }

    private func getNode(at path: [Int], from nodes: [OSCPresetNode]) -> OSCPresetNode {
        var current = nodes[path[0]]
        if path.count == 1 { return current }

        var rest = Array(path.dropFirst())
        while !rest.isEmpty {
            let idx = rest.removeFirst()
            let kids = current.children ?? []
            current = kids[idx]
        }
        return current
    }

    private func setNode(at path: [Int], in nodes: inout [OSCPresetNode], to newNode: OSCPresetNode) {
        guard !path.isEmpty else { return }

        if path.count == 1 {
            nodes[path[0]] = newNode
            return
        }

        var parent = nodes[path[0]]
        var kids = parent.children ?? []
        let rest = Array(path.dropFirst())
        setNode(at: rest, in: &kids, to: newNode)
        parent.children = kids
        nodes[path[0]] = parent
    }
}

// MARK: - UUID wrapper for .sheet(item:)
private struct UUIDBox: Identifiable {
    let id: UUID
}

private struct AddChildByPickerSheet: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    let layoutID: UUID
    @Binding var parentID: UUID?

    @State private var childName: String = ""

    private var lidx: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

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
        NavigationStack {
            Form {
                if let lidx {
                    let options = flatten(store.state.layouts[lidx].presetTree)

                    Section("Parent preset") {
                        Picker("Parent", selection: $parentID) {
                            ForEach(options, id: \.0) { (id, name) in
                                Text(name).tag(Optional(id))
                            }
                        }
                    }

                    Section("Child preset") {
                        TextField("Child name", text: $childName)

                        Button("Create") {
                            let name = childName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty, let pid = parentID else { return }
                            store.addChildPreset(to: layoutID, parentPresetID: pid, name: name)
                            dismiss()
                        }
                    }
                } else {
                    Text("Layout not found.")
                }
            }
            .navigationTitle("Add Child Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

