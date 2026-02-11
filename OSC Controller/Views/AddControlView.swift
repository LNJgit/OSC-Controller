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

    // XY config
    @State private var startX: Float = 0.5
    @State private var startY: Float = 0.5

    // Color config (RGBA 0...1)
    @State private var startR: Float = 1
    @State private var startG: Float = 1
    @State private var startB: Float = 1
    @State private var startA: Float = 1
    @State private var supportsOpacity: Bool = true

    // ✅ Linking
    @State private var alwaysVisible: Bool = true
    @State private var presetIDs: [UUID] = []

    // Tap tempo
    @State private var tapResetSeconds: Float = 2.0
    @State private var startBPM: Float = 120

    // Pad grid
    @State private var gridRows: Int = 4
    @State private var gridCols: Int = 4
    @State private var gridIsMomentary: Bool = true

    // Choice
    @State private var choiceCSV: String = "A,B,C"
    @State private var choiceIndex: Int = 0

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    private var parsedChoiceOptions: [String] {
        choiceCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedAddress.isEmpty else { return false }
        guard trimmedAddress.hasPrefix("/") else { return false }

        if type == .slider || type == .xyPad {
            return maxValue > minValue
        }

        if type == .choice {
            return !parsedChoiceOptions.isEmpty
        }

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

                if type == .xyPad {
                    Section(header: Text("XY Pad Range")) {
                        Text("Min/Max apply to both X and Y.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        numberRow(title: "Min", value: $minValue)
                        numberRow(title: "Max", value: $maxValue)

                        numberRow(title: "Start X", value: $startX)
                        numberRow(title: "Start Y", value: $startY)
                    }
                }

                if type == .tapTempo {
                    Section("Tap Tempo") {
                        numberRow(title: "Start BPM", value: $startBPM)
                        numberRow(title: "Reset seconds", value: $tapResetSeconds)
                        Text("Sends \(address)/tap and \(address)/bpm")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if type == .padGrid {
                    Section("Pad Grid") {
                        Stepper("Rows: \(gridRows)", value: $gridRows, in: 1...16)
                        Stepper("Cols: \(gridCols)", value: $gridCols, in: 1...16)
                        Toggle("Momentary (press/release)", isOn: $gridIsMomentary)

                        Text(gridIsMomentary
                             ? "Sends 1.0 on press and 0.0 on release."
                             : "Toggles state on tap.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if type == .choice {
                    Section("Choice") {
                        TextField("Options (comma-separated)", text: $choiceCSV)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        let maxIdx = max(parsedChoiceOptions.count - 1, 0)
                        Stepper("Default index: \(min(choiceIndex, maxIdx))", value: $choiceIndex, in: 0...maxIdx)

                        if parsedChoiceOptions.isEmpty {
                            Text("Add at least 1 option (e.g. A,B,C).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Sends selected index as Float on \(address)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if type == .color {
                    Section(header: Text("Color Start")) {
                        Toggle("Supports opacity", isOn: $supportsOpacity)

                        numberRow(title: "R (0-1)", value: $startR)
                        numberRow(title: "G (0-1)", value: $startG)
                        numberRow(title: "B (0-1)", value: $startB)

                        if supportsOpacity {
                            numberRow(title: "A (0-1)", value: $startA)
                        } else {
                            Text("Alpha will be forced to 1.0")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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

    private func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }

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

        // Defaults for certain types
        if type == .toggle { control.value = 0 }
        if type == .button { control.value = 0 }

        // XY init
        if type == .xyPad {
            control.x = min(max(startX, minValue), maxValue)
            control.y = min(max(startY, minValue), maxValue)
        }

        // Color init
        if type == .color {
            control.r = clamp01(startR)
            control.g = clamp01(startG)
            control.b = clamp01(startB)
            control.a = supportsOpacity ? clamp01(startA) : 1.0
        }

        // Tap tempo init
        if type == .tapTempo {
            control.value = max(1, startBPM)
            control.tapResetSeconds = max(0.2, tapResetSeconds)
        }

        // Pad grid init
        if type == .padGrid {
            control.gridRows = max(1, gridRows)
            control.gridCols = max(1, gridCols)
            control.gridIsMomentary = gridIsMomentary

            if !gridIsMomentary {
                let count = control.gridRows * control.gridCols
                control.gridStates = Array(repeating: false, count: count)
            } else {
                control.gridStates = []
            }
        }

        // Choice init
        if type == .choice {
            let opts = parsedChoiceOptions.isEmpty ? ["A", "B", "C"] : parsedChoiceOptions
            control.choiceOptions = opts
            control.choiceIndex = min(max(0, choiceIndex), opts.count - 1)
            control.value = Float(control.choiceIndex)
        }

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
