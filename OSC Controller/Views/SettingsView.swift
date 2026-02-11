import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: ControlsStore

    private var selectedLayoutPortString: String {
        if let layoutID = store.state.selectedLayoutID,
           let idx = store.state.layouts.firstIndex(where: { $0.id == layoutID }) {
            let p = store.state.layouts[idx].portString.trimmingCharacters(in: .whitespacesAndNewlines)
            return p.isEmpty ? "9000" : p
        }
        return "9000"
    }

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

                Section(footer: Text("Tip: iPhone + TouchDesigner machine must be on the same Wi-Fi.")) {
                    Button("Test Send /ping") {
                        // Uses the selected layout’s port (each layout can target a different port)
                        store.osc.send("/ping", 1.0, portString: selectedLayoutPortString)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
