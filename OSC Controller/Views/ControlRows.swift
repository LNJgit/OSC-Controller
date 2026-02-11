import SwiftUI
import UIKit

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
                            send(control.address, control.value)
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

        case .xyPad:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(control.name)
                    Spacer()
                    Text("x \(control.x, specifier: "%.2f")  y \(control.y, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                XyPad(
                    x: $control.x,
                    y: $control.y,
                    min: control.min,
                    max: control.max
                ) { x, y in
                    send("\(control.address)/x", x)
                    send("\(control.address)/y", y)
                }
                .frame(height: 160)
            }
            .padding(.vertical, 6)

        case .color:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(control.name)
                    Spacer()
                    ColorSwatch(color: rgbaToColor(r: control.r, g: control.g, b: control.b, a: control.a))
                        .frame(width: 28, height: 28)
                }

                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: { rgbaToColor(r: control.r, g: control.g, b: control.b, a: control.a) },
                        set: { newColor in
                            let rgba = colorToRGBA(newColor)
                            control.r = rgba.r
                            control.g = rgba.g
                            control.b = rgba.b
                            control.a = rgba.a

                            send("\(control.address)/r", control.r)
                            send("\(control.address)/g", control.g)
                            send("\(control.address)/b", control.b)
                            send("\(control.address)/a", control.a)
                        }
                    ),
                    supportsOpacity: true
                )

                HStack {
                    Text("R \(control.r, specifier: "%.2f")  G \(control.g, specifier: "%.2f")  B \(control.b, specifier: "%.2f")  A \(control.a, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.vertical, 6)

        case .tapTempo:
            TapTempoRow(control: $control, send: send)

        case .padGrid:
            PadGridRow(control: $control, send: send)

        case .choice:
            ChoiceRow(control: $control, send: send)
        }
    }
}

// MARK: - Tap Tempo

private struct TapTempoRow: View {
    @Binding var control: OSCControl
    var send: (String, Float) -> Void

    @State private var tapTimes: [TimeInterval] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(control.name)
                Spacer()
                Text("\(control.value, specifier: "%.1f") BPM")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                registerTap()
            } label: {
                Text("Tap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("Sends \(control.address)/tap and \(control.address)/bpm")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func registerTap() {
        let now = Date().timeIntervalSince1970

        // reset if paused too long
        if let last = tapTimes.last, (now - last) > Double(control.tapResetSeconds) {
            tapTimes.removeAll(keepingCapacity: true)
        }
        tapTimes.append(now)

        // send tap trigger
        send("\(control.address)/tap", 1.0)

        // compute BPM
        guard tapTimes.count >= 2 else { return }

        // Use last N taps for stability
        let N = min(6, tapTimes.count)
        let recent = Array(tapTimes.suffix(N))

        var intervals: [Double] = []
        intervals.reserveCapacity(recent.count - 1)
        for i in 1..<recent.count {
            intervals.append(recent[i] - recent[i - 1])
        }

        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return }

        let bpm = Float(60.0 / avg)
        control.value = bpm
        send("\(control.address)/bpm", bpm)
    }
}

// MARK: - Pad Grid

private struct PadGridRow: View {
    @Binding var control: OSCControl
    var send: (String, Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(control.name)

            let rows = max(1, control.gridRows)
            let cols = max(1, control.gridCols)
            let count = rows * cols

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cols),
                spacing: 8
            ) {
                ForEach(0..<count, id: \.self) { idx in
                    let r = idx / cols
                    let c = idx % cols

                    PadCell(
                        isOn: bindingForPad(idx: idx, expectedCount: count),
                        isMomentary: control.gridIsMomentary
                    ) { pressed in
                        let addr = "\(control.address)/\(r)/\(c)"
                        send(addr, pressed ? 1.0 : 0.0)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }

            Text(control.gridIsMomentary
                 ? "Momentary: sends 1.0 press / 0.0 release"
                 : "Toggle: taps switch state")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .onAppear {
            normalizeGridStates()
        }
        .onChange(of: control.gridRows) { _ in
            normalizeGridStates()
        }
        .onChange(of: control.gridCols) { _ in
            normalizeGridStates()
        }
        .onChange(of: control.gridIsMomentary) { _ in
            normalizeGridStates()
        }
    }

    private func normalizeGridStates() {
        let rows = max(1, control.gridRows)
        let cols = max(1, control.gridCols)
        let expected = rows * cols

        // If momentary, we don't store states.
        if control.gridIsMomentary {
            if !control.gridStates.isEmpty {
                control.gridStates = []
            }
            return
        }

        // Toggle mode: ensure exactly expected size.
        if control.gridStates.count != expected {
            if control.gridStates.isEmpty {
                control.gridStates = Array(repeating: false, count: expected)
            } else if control.gridStates.count < expected {
                control.gridStates.append(contentsOf: Array(repeating: false, count: expected - control.gridStates.count))
            } else {
                control.gridStates = Array(control.gridStates.prefix(expected))
            }
        }
    }

    private func bindingForPad(idx: Int, expectedCount: Int) -> Binding<Bool> {
        if control.gridIsMomentary {
            return .constant(false)
        }

        // At this point normalizeGridStates() should have ensured correct sizing,
        // but keep it safe anyway.
        return Binding(
            get: {
                guard control.gridStates.indices.contains(idx) else { return false }
                return control.gridStates[idx]
            },
            set: { newVal in
                guard control.gridStates.indices.contains(idx) else { return }
                control.gridStates[idx] = newVal
            }
        )
    }
}

private struct PadCell: View {
    @State private var isPressed: Bool = false

    var isOn: Binding<Bool>      // used in toggle mode
    let isMomentary: Bool
    var onPressChange: (Bool) -> Void

    var body: some View {
        let active = isMomentary ? isPressed : isOn.wrappedValue

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(active ? .primary : .quaternary)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.tertiary, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(momentaryGesture)
            .onTapGesture {
                guard !isMomentary else { return }
                isOn.wrappedValue.toggle()
                onPressChange(isOn.wrappedValue)
            }
    }

    private var momentaryGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard isMomentary else { return }
                if !isPressed {
                    isPressed = true
                    onPressChange(true)
                }
            }
            .onEnded { _ in
                guard isMomentary else { return }
                if isPressed {
                    isPressed = false
                    onPressChange(false)
                }
            }
    }
}

// MARK: - Choice (single selection)

private struct ChoiceRow: View {
    @Binding var control: OSCControl
    var send: (String, Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(control.name)

            Picker("Choice", selection: Binding(
                get: { control.choiceIndex },
                set: { newIndex in
                    control.choiceIndex = newIndex
                    control.value = Float(newIndex)
                    send(control.address, Float(newIndex))
                }
            )) {
                ForEach(Array(control.choiceOptions.enumerated()), id: \.offset) { idx, label in
                    Text(label).tag(idx)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - XY Pad

private struct XyPad: View {
    @Binding var x: Float
    @Binding var y: Float

    let min: Float
    let max: Float
    var onChange: (Float, Float) -> Void

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        Swift.min(Swift.max(v, lo), hi)
    }

    private func toUnit(_ v: Float) -> Float {
        guard max > min else { return 0 }
        return (v - min) / (max - min)
    }

    private func fromUnit(_ u: Float) -> Float {
        min + u * (max - min)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let unitX = CGFloat(clamp(toUnit(x), 0, 1))
            let unitY = CGFloat(clamp(toUnit(y), 0, 1))

            let px = unitX * size.width
            let py = (1 - unitY) * size.height

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.tertiary, lineWidth: 1)

                Path { p in
                    p.move(to: CGPoint(x: px, y: 0))
                    p.addLine(to: CGPoint(x: px, y: size.height))
                    p.move(to: CGPoint(x: 0, y: py))
                    p.addLine(to: CGPoint(x: size.width, y: py))
                }
                .stroke(.secondary.opacity(0.35), lineWidth: 1)

                Circle()
                    .fill(.primary)
                    .frame(width: 18, height: 18)
                    .position(x: px, y: py)
                    .shadow(radius: 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let loc = value.location
                        let ux = Float(clamp(Float(loc.x / size.width), 0, 1))
                        let uy = Float(clamp(Float(1 - (loc.y / size.height)), 0, 1))

                        x = fromUnit(ux)
                        y = fromUnit(uy)
                        onChange(x, y)
                    }
            )
        }
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

private struct ColorSwatch: View {
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.tertiary, lineWidth: 1)
            )
    }
}


