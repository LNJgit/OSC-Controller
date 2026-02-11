import SwiftUI

struct AddControlView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID
    var onAdd: (OSCControl) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = "Control"
    @State private var address: String = "/control"
    @State private var type: OSCControlType = .slider

    // Slider config
    @State private var minValue: Float = 0
    @State private var maxValue: Float = 1
    @State private var startValue: Float = 0

    // ✅ New model state for linking
    @State private var alwaysVisible: Bool = true
    @State private var presetIDs: [UUID] = []

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return false }
        guard trimmedAddress.hasPrefix("/") else { return false }
        if type == .slider { return maxValue > minValue }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Control")) {
                    TextField("Name", text: $name)
                    addressField

                    Picker("Type", selection: $type) {
                        ForEach(OSCControlType.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                }

                Section("Visibility") {
                    Toggle("Always visible", isOn: $alwaysVisible)

                    if !alwaysVisible {
                        if let lidx = layoutIndex {
                            PresetLinkingView(
                                presetTree: store.state.layouts[lidx].presetTree,
                                presetIDs: $presetIDs
                            )
                        } else {
                            Text("Layout not found.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Tip: Turn this off to show the control only when certain presets are enabled.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if type == .slider {
                    Section(header: Text("Slider Range")) {
                        numberRow(title: "Min", value: $minValue)
                        numberRow(title: "Max", value: $maxValue)
                        numberRow(title: "Start", value: $startValue)
                    }
                }
            }
            .navigationTitle("Add Control")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addControl() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var addressField: some View {
        TextField("OSC Address (e.g. /slider1)", text: $address)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .modifier(AddressAutoSlash(address: $address))
    }

    private func numberRow(title: String, value: Binding<Float>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private func addControl() {
        var finalAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalAddress.hasPrefix("/") { finalAddress = "/" + finalAddress }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        var control = OSCControl(
            name: trimmedName,
            address: finalAddress,
            type: type,
            min: minValue,
            max: maxValue,
            value: startValue
        )

        if type == .toggle { control.value = 0 }
        if type == .button { control.value = 0 }

        // ✅ apply linking state
        control.alwaysVisible = alwaysVisible
        control.presetIDs = presetIDs

        onAdd(control)
        dismiss()
    }
}

// MARK: - Helper Modifier

private struct AddressAutoSlash: ViewModifier {
    @Binding var address: String

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: address) { _, newValue in sanitize(newValue) }
        } else {
            content.onChange(of: address) { sanitize($0) }
        }
    }

    private func sanitize(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !trimmed.hasPrefix("/") { address = "/" + trimmed }
    }
}
