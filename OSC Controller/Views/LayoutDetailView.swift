import SwiftUI

struct LayoutDetailView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID

    @State private var showAddControl = false
    @State private var showLayoutSettings = false
    @State private var showPresets = false

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    // MARK: - Preset evaluation (hierarchical toggles)

    /// Returns preset IDs that are effectively enabled.
    /// A node is effective only if it's ON and all its ancestors are ON.
    private func enabledPresetIDs(from nodes: [OSCPresetNode]) -> Set<UUID> {
        var result = Set<UUID>()

        func walk(_ node: OSCPresetNode, ancestorsOn: Bool) {
            let effectiveOn = ancestorsOn && node.isOn
            if effectiveOn { result.insert(node.id) }

            if let kids = node.children {
                for k in kids {
                    walk(k, ancestorsOn: effectiveOn)
                }
            }
        }

        for n in nodes {
            walk(n, ancestorsOn: true)
        }
        return result
    }

    private func oscSafeSegment(_ s: String) -> String {
        let noDiacritics = s.folding(options: .diacriticInsensitive, locale: .current)
        let spaced = noDiacritics.replacingOccurrences(of: " ", with: "_")

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let cleanedScalars = spaced.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(cleanedScalars))

        return cleaned.isEmpty ? "preset" : cleaned
    }

    /// Visible controls are:
    /// - alwaysVisible == true, OR
    /// - linked to at least one effectively enabled preset.
    private func visibleControlIndices(for layout: OSCLayout) -> [Int] {
        let enabled = enabledPresetIDs(from: layout.presetTree)

        return layout.controls.indices.filter { i in
            let c = layout.controls[i]
            if c.alwaysVisible { return true }
            return c.presetIDs.contains(where: enabled.contains)
        }
    }

    var body: some View {
        Form {
            if let idx = layoutIndex {
                // MARK: Presets (hierarchical toggles)
                Section(header: Text("Presets")) {
                    OutlineGroup($store.state.layouts[idx].presetTree, children: \.children) { nodeBinding in
                        let sendBinding = Binding<Bool>(
                            get: { nodeBinding.wrappedValue.isOn },
                            set: { newValue in
                                nodeBinding.wrappedValue.isOn = newValue

                                let safeName = oscSafeSegment(nodeBinding.wrappedValue.name)
                                let addr = "/preset/\(safeName)"

                                store.send(
                                    layoutID: layoutID,
                                    address: addr,
                                    value: newValue ? 1.0 : 0.0
                                )
                            }
                        )

                        Toggle(nodeBinding.wrappedValue.name, isOn: sendBinding)
                    }

                    Button("Manage presets…") {
                        showPresets = true
                    }
                }

                // MARK: Controls (filtered by toggles)
                Section(header: Text("Controls")) {
                    let indices: [Int] = visibleControlIndices(for: store.state.layouts[idx])

                    ForEach(indices, id: \.self) { i in
                        ControlRow(control: $store.state.layouts[idx].controls[i]) { address, value in
                            store.send(layoutID: layoutID, address: address, value: value)
                        }
                    }
                    .onDelete { offsets in
                        let idsToDelete: [UUID] = offsets.map { store.state.layouts[idx].controls[indices[$0]].id }
                        idsToDelete.forEach { id in
                            store.removeControl(layoutID: layoutID, controlID: id)
                        }
                    }

                    Button("+ Add Control") { showAddControl = true }
                }
            } else {
                Text("Layout not found.")
            }
        }
        .navigationTitle(store.state.layouts.first(where: { $0.id == layoutID })?.name ?? "Layout")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showAddControl = true } label: { Image(systemName: "plus") }
                Button { showLayoutSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                Button { showPresets = true } label: { Image(systemName: "square.grid.2x2") }
            }
        }
        .sheet(isPresented: $showAddControl) {
            AddControlView(layoutID: layoutID) { newControl in
                if let idx = layoutIndex {
                    store.state.layouts[idx].controls.append(newControl)
                }
                showAddControl = false
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showLayoutSettings) {
            LayoutSettingsView(layoutID: layoutID)
        }
        .sheet(isPresented: $showPresets) {
            PresetsView(layoutID: layoutID)
        }
    }
}
