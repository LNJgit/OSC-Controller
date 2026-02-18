import SwiftUI
import UniformTypeIdentifiers

struct LayoutExplorerView: View {
    @EnvironmentObject var store: ControlsStore

    @State private var showCreate = false
    @State private var newLayoutName = ""

    // ✅ Import UI
    @State private var isImportingLayout = false
    @State private var importMessage: String? = nil

    private func importLayout(from url: URL) throws {
        // Security-scoped access for Files/iCloud picked URLs. :contentReference[oaicite:2]{index=2}
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        // Accept either:
        // 1) OSCLayout JSON
        // 2) OSCAppState JSON (imports selected layout if possible, otherwise first)
        let importedLayout: OSCLayout
        if let layout = try? decoder.decode(OSCLayout.self, from: data) {
            importedLayout = layout
        } else if let appState = try? decoder.decode(OSCAppState.self, from: data) {
            if let selected = appState.selectedLayoutID,
               let match = appState.layouts.first(where: { $0.id == selected }) {
                importedLayout = match
            } else if let first = appState.layouts.first {
                importedLayout = first
            } else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Assign fresh IDs so imports never collide
        var layout = importedLayout
        layout.id = UUID()
        layout.controls = layout.controls.map { c in
            var cc = c
            cc.id = UUID()
            return cc
        }

        // Ensure unique name
        let baseName = layout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var name = baseName.isEmpty ? "Imported Layout" : baseName
        if store.state.layouts.contains(where: { $0.name == name }) {
            var i = 2
            while store.state.layouts.contains(where: { $0.name == "\(name) (\(i))" }) { i += 1 }
            name = "\(name) (\(i))"
        }
        layout.name = name

        store.state.layouts.append(layout)
        store.selectLayout(layout.id)

        importMessage = "Imported “\(layout.name)”"
    }

    var body: some View {
        List {
            Section(header: Text("Your Layouts")) {
                if store.state.layouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No layouts yet.")
                            .font(.headline)
                        Text("Tap + to create one, or use Import to load a layout file.")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                } else {
                    ForEach(store.state.layouts) { layout in
                        NavigationLink {
                            LayoutDetailView(layoutID: layout.id)
                        } label: {
                            HStack {
                                Text(layout.name)
                                Spacer()
                                Text("\(layout.controls.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.state.layouts[$0].id }
                        ids.forEach(store.deleteLayout)
                    }
                }
            }
        }
        .navigationTitle("Layouts")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isImportingLayout = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }

                Button {
                    store.duplicateCurrentLayout()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(store.state.layouts.isEmpty || store.currentLayoutIndex == nil)

                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // SwiftUI fileImporter. :contentReference[oaicite:3]{index=3}
        .fileImporter(
            isPresented: $isImportingLayout,
            allowedContentTypes: [.oscLayout, .json],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                try importLayout(from: url)
            } catch {
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Import Layout", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK", role: .cancel) { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    TextField("Layout name", text: $newLayoutName)
                    Button("Create") {
                        let name = newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        store.addLayout(named: name)
                        newLayoutName = ""
                        showCreate = false
                    }
                }
                .navigationTitle("New Layout")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreate = false }
                    }
                }
            }
        }
    }
}
