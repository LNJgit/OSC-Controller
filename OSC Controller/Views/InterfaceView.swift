import SwiftUI

struct InterfaceView: View {
    @EnvironmentObject var store: ControlsStore

    private var layoutIndex: Int? {
        guard let id = store.state.selectedLayoutID else { return nil }
        return store.state.layouts.firstIndex(where: { $0.id == id })
    }

    private func portString(for lidx: Int) -> String {
        let p = store.state.layouts[lidx].portString.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "9000" : p
    }

    var body: some View {
        VStack {
            if let lidx = layoutIndex {
                let layoutID = store.state.layouts[lidx].id
                let port = portString(for: lidx)

                Form {
                    Section(header: Text(store.state.layouts[lidx].name)) {
                        Text("Host: \(store.state.host)")
                        Text("Port: \(port)")
                    }

                    Section(header: Text("Controls")) {
                        // If you later want presets to filter controls here too,
                        // you can apply the same "visible indices" approach as in LayoutDetailView.
                        ForEach(store.state.layouts[lidx].controls.indices, id: \.self) { i in
                            ControlRow(control: $store.state.layouts[lidx].controls[i]) { address, value in
                                // ✅ NEW: pass portString
                                store.osc.send(address, value, portString: port)

                                // Alternative (if you added store.send(layoutID:address:value:))
                                // store.send(layoutID: layoutID, address: address, value: value)
                            }
                        }
                    }
                }
                .navigationTitle("Interface")
                .onAppear {
                    // host is global, keep OSCManager synced
                    store.syncSettingsToOSC()
                }

            } else {
                VStack(spacing: 12) {
                    Text("No layout selected.")
                    Text("Go to Layouts and tap one to start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
}
