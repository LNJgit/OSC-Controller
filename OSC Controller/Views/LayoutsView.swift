import SwiftUI

struct LayoutsView: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Create New Layout")) {
                    TextField("Layout name", text: $newName)
                    Button("Create") {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        store.addLayout(named: name)
                        newName = ""
                    }
                }

                Section(header: Text("Existing Layouts")) {
                    ForEach(store.state.layouts) { layout in
                        HStack {
                            Text(layout.name)
                            Spacer()
                            if store.state.selectedLayoutID == layout.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectLayout(layout.id)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.state.layouts[$0].id }
                        ids.forEach(store.deleteLayout)
                    }

                    Button("Duplicate Current Layout") {
                        store.duplicateCurrentLayout()
                    }
                }
            }
            .navigationTitle("Layouts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
