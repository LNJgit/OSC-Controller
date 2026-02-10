import SwiftUI

struct LayoutExplorerView: View {
    @EnvironmentObject var store: ControlsStore
    @State private var showCreate = false
    @State private var newLayoutName = ""

    var body: some View {
        List {
            Section(header: Text("Your Layouts")) {
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
        .navigationTitle("Layouts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.duplicateCurrentLayout()
                } label: { Image(systemName: "doc.on.doc") }
            }
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
