import SwiftUI

struct GlobalSettingsView: View {
    @EnvironmentObject var store: ControlsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("OSC Destination")) {
                    TextField("Host IP", text: $store.state.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: store.state.host) { _ in
                            store.syncSettingsToOSC()
                        }
                }


                Section {
                    Button("Test /ping") {
                        let layoutPort: String = {
                            if let id = store.state.selectedLayoutID,
                               let idx = store.state.layouts.firstIndex(where: { $0.id == id }) {
                                return store.state.layouts[idx].portString
                            }
                            return store.state.portString
                        }()
                        store.osc.send("/ping", 1.0, portString: layoutPort)
                    }
                }

            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
