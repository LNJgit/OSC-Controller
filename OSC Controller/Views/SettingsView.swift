import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ControlsStore

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OSC Destination")) {
                    TextField("Host IP", text: $store.state.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: store.state.host) { _ in
                            store.syncSettingsToOSC()
                        }

                    TextField("Port", text: $store.state.portString)
                        .keyboardType(.numberPad)
                        .onChange(of: store.state.portString) { _ in
                            store.syncSettingsToOSC()
                        }
                }

                Section(footer: Text("Tip: iPhone + TouchDesigner machine must be on the same Wi-Fi.")) {
                    Button("Test Send /ping") {
                        store.osc.send("/ping", 1.0)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
