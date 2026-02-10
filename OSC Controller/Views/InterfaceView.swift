import SwiftUI

struct InterfaceView: View {
    @EnvironmentObject var store: ControlsStore
    @State private var showAddControl = false
    @State private var showLayouts = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Layout")) {
                    Picker("Active Layout", selection: Binding(
                        get: { store.state.selectedLayoutID ?? store.state.layouts.first?.id },
                        set: { newID in
                            if let id = newID { store.selectLayout(id) }
                        }
                    )) {
                        ForEach(store.state.layouts) { layout in
                            Text(layout.name).tag(Optional(layout.id))
                        }
                    }

                    Button("Manage Layouts") { showLayouts = true }
                }

                Section(header: Text("Controls")) {
                    if let idx = store.currentLayoutIndex {
                        ForEach($store.state.layouts[idx].controls) { $control in
                            ControlRow(control: $control) { address, value in
                                store.osc.send(address, value)
                            }
                        }
                        .onDelete { offsets in
                            store.state.layouts[idx].controls.remove(atOffsets: offsets)
                        }

                        Button("+ Add Control") { showAddControl = true }
                    } else {
                        Text("No layout selected.")
                    }
                }
            }
            .navigationTitle("OSC Controller")
        }
        .sheet(isPresented: $showAddControl) {
            AddControlView { newControl in
                if let idx = store.currentLayoutIndex {
                    store.state.layouts[idx].controls.append(newControl)
                }
                showAddControl = false
            }
        }
        .sheet(isPresented: $showLayouts) {
            LayoutsView()
        }
    }
}
