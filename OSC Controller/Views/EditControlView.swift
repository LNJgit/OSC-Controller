import SwiftUI
import UIKit

/// Full editor for an existing OSCControl.
///
/// Notes:
/// - Uses a custom Binding so edits write directly into `store.state.layouts[...].controls[...]`.
/// - Changing `type` keeps the same ID and address/name, but reinitializes type-specific fields
///   with safe defaults.
struct EditControlView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID
    let controlID: UUID

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    private var controlIndex: Int? {
        guard let lidx = layoutIndex else { return nil }
        return store.state.layouts[lidx].controls.firstIndex(where: { $0.id == controlID })
    }

    private var controlBinding: Binding<OSCControl> {
        Binding(
            get: {
                guard let lidx = layoutIndex, let cidx = controlIndex else {
                    return OSCControl(name: "Missing", address: "/missing", type: .slider)
                }
                return store.state.layouts[lidx].controls[cidx]
            },
            set: { newValue in
                guard let lidx = layoutIndex, let cidx = controlIndex else { return }
                store.state.layouts[lidx].controls[cidx] = newValue
            }
        )
    }

    private var presetTree: [OSCPresetNode] {
        guard let lidx = layoutIndex else { return [] }
        return store.state.layouts[lidx].presetTree
    }

    var body: some View {
        if layoutIndex == nil || controlIndex == nil {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text("Control not found")
                    .font(.headline)
            }
            .foregroundStyle(.secondary)
            .padding()
        } else {
            Form {
                Section("Control") {
                    TextField("Name", text: controlBinding.name)

                    TextField("OSC Address (e.g. /slider1)", text: controlBinding.address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .modifier(AddressAutoSlash(address: controlBinding.address))

                    Picker("Type", selection: controlBinding.type) {
                        ForEach(OSCControlType.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .onChange(of: controlBinding.wrappedValue.type) { _, newType in
                        reinitializeTypeSpecificFields(newType)
                    }
                }

                Section("Visibility") {
                    Toggle("Always visible", isOn: controlBinding.alwaysVisible)
                    if !controlBinding.wrappedValue.alwaysVisible {
                        PresetLinkingView(presetTree: presetTree, presetIDs: controlBinding.presetIDs)
                    } else {
                        Text("Turn this off to show the control only when certain presets are enabled.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                switch controlBinding.wrappedValue.type {
                case .slider:
                    sliderSection
                case .xyPad:
                    xySection
                case .color:
                    colorSection
                case .tapTempo:
                    tapTempoSection
                case .padGrid:
                    padGridSection
                case .choice:
                    choiceSection
                case .button, .toggle:
                    EmptyView()
                }
            }
            .navigationTitle("Edit Control")
        }
    }
}

// MARK: - Sections

private extension EditControlView {
    var sliderSection: some View {
        Section("Slider Range") {
            numberRow(title: "Min", value: controlBinding.min)
            numberRow(title: "Max", value: controlBinding.max)
            numberRow(title: "Value", value: controlBinding.value)

            if controlBinding.wrappedValue.max <= controlBinding.wrappedValue.min {
                Text("Max must be greater than Min.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    var xySection: some View {
        Section("XY Pad") {
            Text("Min/Max apply to both X and Y.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            numberRow(title: "Min", value: controlBinding.min)
            numberRow(title: "Max", value: controlBinding.max)
            numberRow(title: "X", value: controlBinding.x)
            numberRow(title: "Y", value: controlBinding.y)
        }
    }

    var tapTempoSection: some View {
        Section("Tap Tempo") {
            numberRow(title: "BPM", value: controlBinding.value)
            numberRow(title: "Reset seconds", value: controlBinding.tapResetSeconds)
            Text("Sends \(controlBinding.wrappedValue.address)/tap and \(controlBinding.wrappedValue.address)/bpm")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var padGridSection: some View {
        Section("Pad Grid") {
            Stepper("Rows: \(controlBinding.wrappedValue.gridRows)", value: controlBinding.gridRows, in: 1...16)
                .onChange(of: controlBinding.wrappedValue.gridRows) { _, _ in normalizeGridStates() }
            Stepper("Cols: \(controlBinding.wrappedValue.gridCols)", value: controlBinding.gridCols, in: 1...16)
                .onChange(of: controlBinding.wrappedValue.gridCols) { _, _ in normalizeGridStates() }

            Toggle("Momentary (press/release)", isOn: controlBinding.gridIsMomentary)
                .onChange(of: controlBinding.wrappedValue.gridIsMomentary) { _, _ in normalizeGridStates() }

            Text(controlBinding.wrappedValue.gridIsMomentary
                 ? "Sends 1.0 on press and 0.0 on release."
                 : "Toggles state on tap.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .onAppear { normalizeGridStates() }
    }

    var choiceSection: some View {
        Section("Choice") {
            TextField("Options (comma-separated)", text: choiceCSVBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            let maxIdx = max(controlBinding.wrappedValue.choiceOptions.count - 1, 0)
            Stepper(
                "Selected index: \(min(controlBinding.wrappedValue.choiceIndex, maxIdx))",
                value: controlBinding.choiceIndex,
                in: 0...maxIdx
            )
            .onChange(of: controlBinding.wrappedValue.choiceIndex) { _, newVal in
                controlBinding.value.wrappedValue = Float(newVal)
            }

            if controlBinding.wrappedValue.choiceOptions.isEmpty {
                Text("Add at least 1 option (e.g. A,B,C).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sends selected index as Float on \(controlBinding.wrappedValue.address)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var colorSection: some View {
        Section("Color") {
            ColorPicker(
                "Color",
                selection: Binding(
                    get: {
                        rgbaToColor(r: controlBinding.wrappedValue.r,
                                   g: controlBinding.wrappedValue.g,
                                   b: controlBinding.wrappedValue.b,
                                   a: controlBinding.wrappedValue.a)
                    },
                    set: { newColor in
                        let rgba = colorToRGBA(newColor)
                        controlBinding.r.wrappedValue = rgba.r
                        controlBinding.g.wrappedValue = rgba.g
                        controlBinding.b.wrappedValue = rgba.b
                        controlBinding.a.wrappedValue = rgba.a
                    }
                ),
                supportsOpacity: true
            )

            numberRow(title: "R (0-1)", value: controlBinding.r)
            numberRow(title: "G (0-1)", value: controlBinding.g)
            numberRow(title: "B (0-1)", value: controlBinding.b)
            numberRow(title: "A (0-1)", value: controlBinding.a)
        }
    }
}

// MARK: - Helpers

private extension EditControlView {
    func numberRow(title: String, value: Binding<Float>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    /// CSV editor backed by `control.choiceOptions`.
    var choiceCSVBinding: Binding<String> {
        Binding(
            get: {
                controlBinding.wrappedValue.choiceOptions.joined(separator: ",")
            },
            set: { newCSV in
                let opts = newCSV
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                controlBinding.choiceOptions.wrappedValue = opts

                let maxIdx = max(opts.count - 1, 0)
                if opts.isEmpty {
                    controlBinding.choiceIndex.wrappedValue = 0
                    controlBinding.value.wrappedValue = 0
                } else {
                    let clamped = min(max(controlBinding.wrappedValue.choiceIndex, 0), maxIdx)
                    controlBinding.choiceIndex.wrappedValue = clamped
                    controlBinding.value.wrappedValue = Float(clamped)
                }
            }
        )
    }

    func normalizeGridStates() {
        let rows = max(1, controlBinding.wrappedValue.gridRows)
        let cols = max(1, controlBinding.wrappedValue.gridCols)
        let expected = rows * cols

        if controlBinding.wrappedValue.gridIsMomentary {
            if !controlBinding.wrappedValue.gridStates.isEmpty {
                controlBinding.gridStates.wrappedValue = []
            }
            return
        }

        var states = controlBinding.wrappedValue.gridStates
        if states.count != expected {
            if states.isEmpty {
                states = Array(repeating: false, count: expected)
            } else if states.count < expected {
                states.append(contentsOf: Array(repeating: false, count: expected - states.count))
            } else {
                states = Array(states.prefix(expected))
            }
            controlBinding.gridStates.wrappedValue = states
        }
    }

    func reinitializeTypeSpecificFields(_ newType: OSCControlType) {
        // Keep name/address/id. Reset only things that don't make sense across types.
        switch newType {
        case .slider:
            controlBinding.min.wrappedValue = 0
            controlBinding.max.wrappedValue = 1
            controlBinding.value.wrappedValue = 0

        case .toggle:
            controlBinding.value.wrappedValue = 0

        case .button:
            controlBinding.value.wrappedValue = 0

        case .xyPad:
            controlBinding.min.wrappedValue = 0
            controlBinding.max.wrappedValue = 1
            controlBinding.x.wrappedValue = 0.5
            controlBinding.y.wrappedValue = 0.5

        case .color:
            controlBinding.r.wrappedValue = 1
            controlBinding.g.wrappedValue = 1
            controlBinding.b.wrappedValue = 1
            controlBinding.a.wrappedValue = 1

        case .tapTempo:
            controlBinding.value.wrappedValue = 120
            controlBinding.tapResetSeconds.wrappedValue = 2.0

        case .padGrid:
            controlBinding.gridRows.wrappedValue = 4
            controlBinding.gridCols.wrappedValue = 4
            controlBinding.gridIsMomentary.wrappedValue = true
            controlBinding.gridStates.wrappedValue = []

        case .choice:
            controlBinding.choiceOptions.wrappedValue = ["A", "B", "C"]
            controlBinding.choiceIndex.wrappedValue = 0
            controlBinding.value.wrappedValue = 0
        }
    }
}

// MARK: - Address auto-slash

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

// MARK: - Color helpers

private func rgbaToColor(r: Float, g: Float, b: Float, a: Float) -> Color {
    Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
}

private func colorToRGBA(_ color: Color) -> (r: Float, g: Float, b: Float, a: Float) {
    let ui = UIColor(color)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Float(r), Float(g), Float(b), Float(a))
}
