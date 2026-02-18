import SwiftUI
import UniformTypeIdentifiers

struct LayoutDetailView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID

    private enum ActiveSheet: Identifiable {
        case addControl
        case layoutSettings
        case presets

        var id: Int {
            switch self {
            case .addControl: return 0
            case .layoutSettings: return 1
            case .presets: return 2
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil

    // Export only
    @State private var isExportingLayout = false
    @State private var exportDoc: OSCLayoutDocument? = nil
    @State private var exportErrorMessage: String? = nil

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    private struct ControlSectionModel: Identifiable {
        let id: String
        let title: String
        let indices: [Int]
    }

    private func enabledPresetIDs(from nodes: [OSCPresetNode]) -> Set<UUID> {
        var result = Set<UUID>()

        func walk(_ node: OSCPresetNode, ancestorsOn: Bool) {
            let effectiveOn = ancestorsOn && node.isOn
            if effectiveOn { result.insert(node.id) }
            if let kids = node.children {
                for k in kids { walk(k, ancestorsOn: effectiveOn) }
            }
        }

        for n in nodes { walk(n, ancestorsOn: true) }
        return result
    }

    private func enabledPresetsInOrder(from nodes: [OSCPresetNode]) -> [(UUID, String)] {
        var out: [(UUID, String)] = []

        func walk(_ node: OSCPresetNode, ancestorsOn: Bool) {
            let effectiveOn = ancestorsOn && node.isOn
            if effectiveOn { out.append((node.id, node.name)) }
            if let kids = node.children {
                for k in kids { walk(k, ancestorsOn: effectiveOn) }
            }
        }

        for n in nodes { walk(n, ancestorsOn: true) }
        return out
    }

    private func oscSafeSegment(_ s: String) -> String {
        let noDiacritics = s.folding(options: .diacriticInsensitive, locale: .current)
        let spaced = noDiacritics.replacingOccurrences(of: " ", with: "_")

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let cleanedScalars = spaced.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(cleanedScalars))

        return cleaned.isEmpty ? "name" : cleaned.lowercased()
    }

    private func visibleControlIndices(for layout: OSCLayout) -> [Int] {
        let enabled = enabledPresetIDs(from: layout.presetTree)
        return layout.controls.indices.filter { i in
            let c = layout.controls[i]
            if c.alwaysVisible { return true }
            return c.presetIDs.contains(where: enabled.contains)
        }
    }

    private func primaryEnabledPresetID(for control: OSCControl, enabledPresetsOrdered: [(UUID, String)]) -> UUID? {
        for (pid, _) in enabledPresetsOrdered {
            if control.presetIDs.contains(pid) { return pid }
        }
        return nil
    }

    private func buildControlSections(layout: OSCLayout) -> [ControlSectionModel] {
        let visible = visibleControlIndices(for: layout)
        let enabledOrdered = enabledPresetsInOrder(from: layout.presetTree)
        let enabledSet = Set(enabledOrdered.map { $0.0 })

        let always = visible.filter { layout.controls[$0].alwaysVisible }
        let presetVisible = visible.filter { !layout.controls[$0].alwaysVisible }

        var byPreset: [UUID: [Int]] = [:]
        var other: [Int] = []

        for ci in presetVisible {
            let c = layout.controls[ci]
            if let pid = primaryEnabledPresetID(for: c, enabledPresetsOrdered: enabledOrdered),
               enabledSet.contains(pid) {
                byPreset[pid, default: []].append(ci)
            } else {
                other.append(ci)
            }
        }

        var sections: [ControlSectionModel] = []

        if !always.isEmpty {
            sections.append(ControlSectionModel(id: "always", title: "Always Visible", indices: always))
        }

        for (pid, pname) in enabledOrdered {
            if let arr = byPreset[pid], !arr.isEmpty {
                sections.append(ControlSectionModel(id: "preset-\(pid.uuidString)", title: pname, indices: arr))
            }
        }

        if !other.isEmpty {
            sections.append(ControlSectionModel(id: "other", title: "Other Controls", indices: other))
        }

        return sections
    }

    private func addressWithControlName(control: OSCControl, rawAddress: String) -> String {
        let safeName = oscSafeSegment(control.name)
        let base = control.address.hasPrefix("/") ? control.address : "/" + control.address

        if rawAddress.hasPrefix(base) {
            let suffix = String(rawAddress.dropFirst(base.count))
            return base + "/" + safeName + suffix
        }

        if rawAddress.hasPrefix("/") {
            return base + "/" + safeName + rawAddress
        } else {
            return base + "/" + safeName + "/" + rawAddress
        }
    }

    private func sendControl(layoutIdx: Int, controlIndex: Int, rawAddress: String, value: Float) {
        let c = store.state.layouts[layoutIdx].controls[controlIndex]
        let finalAddr = addressWithControlName(control: c, rawAddress: rawAddress)
        store.send(layoutID: layoutID, address: finalAddr, value: value)
    }

    private func deleteControls(layoutIdx: Int, sectionIndices: [Int], offsets: IndexSet) {
        let idsToDelete: [UUID] = offsets.map { store.state.layouts[layoutIdx].controls[sectionIndices[$0]].id }
        idsToDelete.forEach { id in
            store.removeControl(layoutID: layoutID, controlID: id)
        }
    }

    var body: some View {
        Form {
            if let idx = layoutIndex {
                let layout = store.state.layouts[idx]

                Section(header: Text("Presets")) {
                    OutlineGroup($store.state.layouts[idx].presetTree, children: \.children) { nodeBinding in
                        let sendBinding = Binding<Bool>(
                            get: { nodeBinding.wrappedValue.isOn },
                            set: { newValue in
                                nodeBinding.wrappedValue.isOn = newValue
                                let safeName = oscSafeSegment(nodeBinding.wrappedValue.name)
                                let addr = "/preset/\(safeName)"
                                store.send(layoutID: layoutID, address: addr, value: newValue ? 1.0 : 0.0)
                            }
                        )
                        Toggle(nodeBinding.wrappedValue.name, isOn: sendBinding)
                    }

                    Button("Manage presets…") { activeSheet = .presets }
                }

                let sections = buildControlSections(layout: layout)

                ForEach(sections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.indices, id: \.self) { i in
                            ControlRow(control: $store.state.layouts[idx].controls[i]) { address, value in
                                sendControl(layoutIdx: idx, controlIndex: i, rawAddress: address, value: value)
                            }
                        }
                        .onDelete { offsets in
                            deleteControls(layoutIdx: idx, sectionIndices: section.indices, offsets: offsets)
                        }
                    }
                }

                Section {
                    Button("+ Add Control") { activeSheet = .addControl }
                }

            } else {
                Text("Layout not found.")
            }
        }
        .navigationTitle(store.state.layouts.first(where: { $0.id == layoutID })?.name ?? "Layout")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    guard let idx = layoutIndex else { return }
                    exportDoc = OSCLayoutDocument(layout: store.state.layouts[idx])
                    isExportingLayout = true
                } label: {
                    Label("Export layout", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)

                Button { activeSheet = .addControl } label: {
                    Label("Add control", systemImage: "plus")
                }
                .labelStyle(.iconOnly)

                Button { activeSheet = .layoutSettings } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .labelStyle(.iconOnly)

                Button { activeSheet = .presets } label: {
                    Label("Presets", systemImage: "square.grid.2x2")
                }
                .labelStyle(.iconOnly)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addControl:
                AddControlView(layoutID: layoutID) { newControl in
                    if let idx = layoutIndex {
                        store.state.layouts[idx].controls.append(newControl)
                    }
                    activeSheet = nil
                }
                .environmentObject(store)

            case .layoutSettings:
                LayoutSettingsView(layoutID: layoutID).environmentObject(store)

            case .presets:
                PresetsView(layoutID: layoutID).environmentObject(store)
            }
        }
        .fileExporter(
            isPresented: $isExportingLayout,
            document: exportDoc,
            contentType: .json,
            defaultFilename: (store.state.layouts.first(where: { $0.id == layoutID })?.name ?? "Layout")
        ) { result in
            if case .failure(let err) = result {
                exportErrorMessage = "Export failed: \(err.localizedDescription)"
            }
        }
        .alert("Export Layout", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }
}
