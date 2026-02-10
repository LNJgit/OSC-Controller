import SwiftUI

struct LayoutSettingsView: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss
    let layoutID: UUID

    private var idx: Int? { store.state.layouts.firstIndex(where: { $0.id == layoutID }) }

    var body: some View {
        NavigationStack {
            Form {
                if let idx {
                    Section(header: Text("Layout")) {
                        TextField("Name", text: $store.state.layouts[idx].name)
                    }

                    Section {
                        Button(role: .destructive) {
                            store.deleteLayout(layoutID)
                            dismiss()
                        } label: {
                            Text("Delete Layout")
                        }
                    }
                } else {
                    Text("Layout not found.")
                }
            }
            .navigationTitle("Layout Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
