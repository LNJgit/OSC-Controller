import SwiftUI

struct LayoutDetailView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID

    @State private var showAddControl = false
    @State private var showLayoutSettings = false
    @State private var showGlobalSettings = false

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    var body: some View {
        Form {
            if let idx = layoutIndex {
                Section(header: Text("Controls")) {
                    ForEach($store.state.layouts[idx].controls) { $control in
                        ControlRow(control: $control) { address, value in
                            store.osc.send(address, value)
                        }
                    }
                    .onDelete { offsets in
                        store.state.layouts[idx].controls.remove(atOffsets: offsets)
                    }

                    Button("+ Add Control") { showAddControl = true }
                }
            } else {
                Text("Layout not found.")
            }
        }
        .navigationTitle(store.state.layouts.first(where: { $0.id == layoutID })?.name ?? "Layout")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddControl = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showLayoutSettings = true } label: { Image(systemName: "slider.horizontal.3") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showGlobalSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showAddControl) {
            AddControlView { newControl in
                if let idx = layoutIndex {
                    store.state.layouts[idx].controls.append(newControl)
                }
                showAddControl = false
            }
        }
        .sheet(isPresented: $showLayoutSettings) {
            LayoutSettingsView(layoutID: layoutID)
        }
        .sheet(isPresented: $showGlobalSettings) {
            GlobalSettingsView()
        }
    }
}
