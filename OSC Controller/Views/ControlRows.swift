import SwiftUI

struct ControlRow: View {
    @Binding var control: OSCControl
    var send: (String, Float) -> Void

    var body: some View {
        switch control.type {
        case .slider:
            VStack(alignment: .leading) {
                HStack {
                    Text(control.name)
                    Spacer()
                    Text("\(control.value, specifier: "%.2f")")
                }
                Slider(
                    value: Binding(
                        get: { Double(control.value) },
                        set: { newVal in
                            control.value = Float(newVal)
                            send(control.address, control.value) // ✅ send on change
                        }
                    ),
                    in: Double(control.min)...Double(control.max)
                )
            }

        case .toggle:
            Toggle(control.name, isOn: Binding(
                get: { control.value > 0.5 },
                set: { on in
                    control.value = on ? 1 : 0
                    send(control.address, control.value)
                }
            ))

        case .button:
            Button(control.name) {
                send(control.address, 1.0)
            }
        }
    }
}
