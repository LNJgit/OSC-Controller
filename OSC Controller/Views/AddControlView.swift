//
//  AddControlView.swift
//  OSC Controller
//

import SwiftUI

struct AddControlView: View {
    var onAdd: (OSCControl) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = "Control"
    @State private var address: String = "/control"
    @State private var type: OSCControlType = .slider

    // Slider config
    @State private var minValue: Float = 0
    @State private var maxValue: Float = 1
    @State private var startValue: Float = 0

    // Basic validation
    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return false }
        guard trimmedAddress.hasPrefix("/") else { return false } // OSC address pattern should start with '/'
        if type == .slider { return maxValue > minValue }
        return true
    }

    var body: some View {
        NavigationView {
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

                if type == .slider {
                    Section(header: Text("Slider Range")) {
                        numberRow(title: "Min", value: $minValue)
                        numberRow(title: "Max", value: $maxValue)
                        numberRow(title: "Start", value: $startValue)

                        Text("Tip: Start should be between Min and Max.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section(footer: Text("Buttons send 1.0 when tapped. Toggles send 0/1.").font(.footnote)) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Add Control")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addControl()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Subviews

    private var addressField: some View {
        Group {
            #if os(iOS)
            TextField("OSC Address (e.g. /slider1)", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.default)
                .modifier(AddressAutoSlash(address: $address))
            #else
            TextField("OSC Address (e.g. /slider1)", text: $address)
                .modifier(AddressAutoSlash(address: $address))
            #endif
        }
    }

    private func numberRow(title: String, value: Binding<Float>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
        }
    }

    // MARK: - Actions

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

        // For non-slider types, we can normalize defaults
        if type == .toggle { control.value = 0 }
        if type == .button { control.value = 0 }

        onAdd(control)
        dismiss()
    }
}

// MARK: - Helper Modifier: auto-prepend "/" to OSC address

private struct AddressAutoSlash: ViewModifier {
    @Binding var address: String

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .onChange(of: address) { _, newValue in
                    sanitize(newValue)
                }
        } else {
            content
                .onChange(of: address) { newValue in
                    sanitize(newValue)
                }
        }
    }

    private func sanitize(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !trimmed.hasPrefix("/") {
            address = "/" + trimmed
        }
    }
}
