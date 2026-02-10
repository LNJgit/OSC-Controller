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
                        .onChange(of: store.state.host) { _ in store.syncSettingsToOSC() }

                    TextField("Port", text: $store.state.portString)
                        .keyboardType(.numberPad)
                        .onChange(of: store.state.portString) { _ in store.syncSettingsToOSC() }
                }

                Section {
                    Button("Test /ping") { store.osc.send("/ping", 1.0) }
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
