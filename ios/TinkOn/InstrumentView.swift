import SwiftUI
import UIKit

enum Panel {
    static let ink = Color(red: 28/255, green: 29/255, blue: 32/255)
    static let chassis = Color(red: 236/255, green: 238/255, blue: 240/255)
    static let paper = Color(red: 244/255, green: 245/255, blue: 247/255)
    static let muted = Color(red: 103/255, green: 107/255, blue: 114/255)
    static let border = ink.opacity(0.22)
    static let indicatorCornerRadius: CGFloat = 3
    static let logoCornerRadius: CGFloat = 1.5
    static let keyCornerRadius: CGFloat = 7
    static let panelCornerRadius: CGFloat = 10
    static let padCornerRadius: CGFloat = 9
    static let padLabelHeight: CGFloat = 17
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

private struct SketchLayout {
    let width: CGFloat
    let canvasHeight: CGFloat
    let promptHeight: CGFloat

    init(size: CGSize, regular: Bool) {
        width = max(1, size.width)
        promptHeight = regular ? 82 : 62
        canvasHeight = max(1, size.height - (regular ? 64 : 52) - promptHeight - 1)
    }

    var drawingAspectRatio: CGFloat { width / canvasHeight }
}

// Solve both panes together: every pad and the sketch use the same drawing
// proportions, while the canvas and grid fill the height above their controls.
private struct InstrumentLayout {
    let wide: Bool
    let columns: Int
    let sketchSize: CGSize

    init(size: CGSize, regular: Bool, padCount: Int) {
        wide = size.width > size.height
        columns = 4
        let rows = CGFloat(padCount / columns)
        let columnCount = CGFloat(columns)
        let height = max(1, size.height - 45)
        let sketchControls: CGFloat = regular ? 147 : 115
        let padControls: CGFloat = regular ? 175 : 163
        let gaps = 7 * (rows - 1)
        if wide {
            let canvasHeight = max(1, height - sketchControls)
            let artworkHeight = max(1, (height - padControls - gaps) / rows - Panel.padLabelHeight)
            let usableWidth = max(1, size.width - 25 - 7 * (columnCount - 1))
            let fittedWidth = usableWidth * canvasHeight / (canvasHeight + columnCount * artworkHeight)
            let toolbarWidth: CGFloat = regular ? 336 : 280
            let width = min(size.width * 0.55, max(toolbarWidth, fittedWidth))
            sketchSize = CGSize(width: width, height: height)
        } else {
            let padWidth = max(1, (size.width - 24 - 7 * (columnCount - 1)) / columnCount)
            let available = height - 1 - padControls - gaps - rows * Panel.padLabelHeight
            let fittedHeight = (size.width * available + rows * padWidth * sketchControls)
                / (size.width + rows * padWidth)
            let maximumHeight = height - 1 - padControls - gaps - rows * 44
            let sketchHeight = max(sketchControls + 100, min(maximumHeight, fittedHeight))
            sketchSize = CGSize(width: size.width, height: sketchHeight)
        }
    }
}

private struct PitchSlider: UIViewRepresentable {
    let value: Double
    let onChange: (Double) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> FlatPitchSlider {
        let slider = FlatPitchSlider()
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: FlatPitchSlider, context: Context) {
        context.coordinator.onChange = onChange
        slider.setValue(Float(value), animated: false)
        slider.isEnabled = isEnabled
        slider.alpha = isEnabled ? 1 : 0.45
        slider.accessibilityValue = "\(Int(value)) semitones"
    }

    final class Coordinator: NSObject {
        var onChange: (Double) -> Void
        init(onChange: @escaping (Double) -> Void) { self.onChange = onChange }
        @objc func changed(_ slider: UISlider) {
            slider.value = slider.value.rounded()
            slider.accessibilityValue = "\(Int(slider.value)) semitones"
            onChange(Double(slider.value))
        }
    }
}

private final class FlatPitchSlider: UISlider {
    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumValue = -12
        maximumValue = 12
        accessibilityLabel = "Pad pitch"
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 16)).image { _ in
            let shape = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 12, height: 16), cornerRadius: Panel.indicatorCornerRadius)
            UIColor(Panel.ink).setFill()
            shape.fill()
        }
        for state in [UIControl.State.normal, .highlighted, .disabled] {
            setThumbImage(thumb, for: state)
            setMinimumTrackImage(Self.trackImage(UIColor(Panel.ink)), for: state)
            setMaximumTrackImage(Self.trackImage(UIColor(Panel.border)), for: state)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: 6, y: bounds.midY - 1, width: max(1, bounds.width - 12), height: 2)
    }

    override func accessibilityIncrement() { adjust(by: 1) }
    override func accessibilityDecrement() { adjust(by: -1) }

    private func adjust(by step: Float) {
        value = min(maximumValue, max(minimumValue, value + step))
        sendActions(for: .valueChanged)
    }

    private static func trackImage(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 3, height: 2)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1))
    }
}

struct PanelKeyStyle: ButtonStyle {
    var prominent = false
    var faceHeight: CGFloat? = nil
    var faceWidth: CGFloat? = nil
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let filled = prominent != configuration.isPressed
        return configuration.label
            .foregroundStyle(filled ? Panel.paper : Panel.ink)
            .background(RoundedRectangle(cornerRadius: Panel.keyCornerRadius).fill(filled ? Panel.ink : Panel.chassis).frame(width: faceWidth, height: faceHeight))
            .overlay(RoundedRectangle(cornerRadius: Panel.keyCornerRadius).stroke(Panel.border, lineWidth: 1).frame(width: faceWidth, height: faceHeight))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct PanelIconStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Panel.ink)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.45)
    }
}

struct InstrumentView: View {
    @ObservedObject var instrument: Instrument
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geometry in
            let regular = horizontalSizeClass == .regular
            let layout = InstrumentLayout(size: geometry.size, regular: regular, padCount: instrument.padCapacity)
            let sketchLayout = SketchLayout(size: layout.sketchSize, regular: regular)
            VStack(spacing: 0) {
                masthead
                Rectangle().fill(Panel.border).frame(height: 1)
                if layout.wide {
                    HStack(spacing: 0) {
                        sketchPane(layout: sketchLayout).frame(width: layout.sketchSize.width)
                        Rectangle().fill(Panel.border).frame(width: 1)
                        padPane(drawingAspectRatio: sketchLayout.drawingAspectRatio, columns: layout.columns)
                    }
                } else {
                    VStack(spacing: 0) {
                        sketchPane(layout: sketchLayout).frame(height: layout.sketchSize.height)
                        Rectangle().fill(Panel.border).frame(height: 1)
                        padPane(drawingAspectRatio: sketchLayout.drawingAspectRatio, columns: layout.columns)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Panel.chassis.ignoresSafeArea())
        .foregroundStyle(Panel.ink)
        .disabled(instrument.showAIConsent)
        .allowsHitTesting(!instrument.showAIConsent)
        .accessibilityHidden(instrument.showAIConsent)
        .overlay {
            if instrument.showAIConsent {
                AIConsentPanel(instrument: instrument)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            SettingsView(instrument: instrument)
                .presentationBackground(Panel.chassis)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Panel.panelCornerRadius)
        }
        .sheet(item: $instrument.sharedAudio) { audio in ShareSheet(url: audio.url) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { instrument.pauseForSystemEvent() }
        }
    }

    private var masthead: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: Panel.logoCornerRadius).fill(Panel.ink).frame(width: 9, height: 9)
            Text("TINK-ON").font(Panel.mono(14, .bold)).tracking(2)
            Text("S-4 SKETCH SAMPLER").font(Panel.mono(9)).foregroundStyle(Panel.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Button(action: instrument.sharePad) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PanelIconStyle())
            .disabled(instrument.selectedPad == nil)
            .accessibilityLabel("Share selected pad as WAV")
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PanelIconStyle())
            .accessibilityLabel("Settings and help")
        }
        .padding(.horizontal, 14).frame(height: 44)
    }

    private func sketchPane(layout: SketchLayout) -> some View {
        VStack(spacing: 0) {
            ZStack {
                SketchView(strokes: instrument.kit.strokes, ink: instrument.kit.ink) { stroke in
                    instrument.setStrokes(instrument.kit.strokes + [stroke])
                }
                .frame(width: layout.width, height: layout.canvasHeight)
                .overlay { Rectangle().stroke(Panel.border, lineWidth: 1) }
                if instrument.kit.strokes.isEmpty {
                    VStack(spacing: 6) {
                        Text("[ SKETCH A SOUND ]").font(Panel.mono(11, .medium))
                        Text("shape · speed · ink").font(Panel.mono(9))
                    }.foregroundStyle(Panel.muted).allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Panel.chassis)
            .clipped()
            Rectangle().fill(Panel.border).frame(height: 1)
            sketchToolbar
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(instrument.kit.aiEnabled ? "PROMPT · AI + SYNTH" : "PROMPT · SYNTH").font(Panel.mono(8)).foregroundStyle(Panel.muted)
                    Text(instrument.message).font(Panel.mono(10)).lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("statusMessage")
                }.padding(.horizontal, 11).padding(.vertical, layout.promptHeight < 74 ? 6 : 12)
                Button(action: instrument.generate) {
                    Text(instrument.generating ? "WAIT" : "GENERATE")
                        .font(Panel.mono(10, .bold)).tracking(0.5)
                        .frame(width: 84, height: 44)
                }
                .buttonStyle(PanelKeyStyle(prominent: true, faceHeight: 30))
                .padding(.trailing, horizontalSizeClass == .regular ? 12 : 8)
                .disabled(instrument.generating)
                .accessibilityIdentifier("generateButton")
            }.frame(height: layout.promptHeight)
                .overlay(alignment: .top) { Rectangle().fill(Panel.border).frame(height: 1) }
        }
    }

    private var sketchToolbar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Ink.allCases) { ink in
                    Button { instrument.selectInk(ink) } label: {
                        Circle().fill(ink.color)
                            .frame(width: horizontalSizeClass == .regular ? 40 : 21,
                                   height: horizontalSizeClass == .regular ? 40 : 21)
                            .overlay(Circle().stroke(Panel.border, lineWidth: 1))
                            .padding(4)
                            .overlay(Circle().stroke(instrument.kit.ink == ink ? Panel.ink : .clear, lineWidth: 1.5))
                            .frame(width: horizontalSizeClass == .regular ? 56 : 44,
                                   height: horizontalSizeClass == .regular ? 56 : 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(ink.rawValue) ink, \(ink.timbre)")
                    .accessibilityAddTraits(instrument.kit.ink == ink ? .isSelected : [])
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                chip("UNDO", label: "Undo last stroke", action: instrument.undo)
                    .disabled(instrument.kit.strokes.isEmpty)
                chip("CLR", label: "Clear sketch", action: instrument.clearSketch)
                    .disabled(instrument.kit.strokes.isEmpty)
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 12 : 8)
        .frame(height: horizontalSizeClass == .regular ? 64 : 52)
        .background(Panel.chassis)
    }

    private func padPane(drawingAspectRatio: CGFloat, columns: Int) -> some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let gap: CGFloat = 7
                let rows = instrument.padCapacity / columns
                let columnWidth = max(1, (proxy.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns))
                let rowHeight = max(1, (proxy.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
                let tileWidth = max(44, min(columnWidth,
                    (rowHeight - Panel.padLabelHeight) * drawingAspectRatio))
                let tileHeight = tileWidth / drawingAspectRatio + Panel.padLabelHeight
                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<columns, id: \.self) { column in
                                let slot = row * columns + column
                                PadTile(pad: instrument.kit.pads[slot], number: slot + 1,
                                        selected: instrument.kit.selected == slot,
                                        flashing: instrument.flashes.contains(slot)) { instrument.tap(slot) }
                                    .frame(width: tileWidth, height: tileHeight)
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 6) {
                Text(instrument.selectedPad != nil ? "P\(instrument.kit.selected + 1)" : "NO PAD")
                    .font(Panel.mono(10, .semibold)).frame(width: 48, alignment: .leading)
                Text("PITCH").font(Panel.mono(8)).foregroundStyle(Panel.muted)
                PitchSlider(value: Double(instrument.selectedPad?.pitch ?? 0), onChange: instrument.setPitch)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .disabled(instrument.selectedPad == nil)
                Text(String(format: "%+d", instrument.selectedPad?.pitch ?? 0)).font(Panel.mono(10)).frame(width: 26)
                chip("DEL", label: "Delete selected pad", action: instrument.deletePad).disabled(instrument.selectedPad == nil)
            }
            .padding(.horizontal, 9).frame(height: 44)
            .overlay(RoundedRectangle(cornerRadius: Panel.panelCornerRadius).stroke(Panel.border))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button(action: instrument.toggleTransport) {
                        Text(instrument.playing ? "STOP" : "PLAY").font(Panel.mono(10, .semibold)).tracking(1)
                            .frame(width: 58, height: 44)
                    }.buttonStyle(PanelKeyStyle(prominent: instrument.playing, faceHeight: 30))
                        .frame(height: 44).accessibilityIdentifier("transportButton")
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(instrument.kit.bpm)").font(Panel.mono(12, .semibold))
                            Text("BPM").font(Panel.mono(8)).foregroundStyle(Panel.muted)
                        }.fixedSize(horizontal: true, vertical: false)
                            .frame(width: 52).accessibilityElement(children: .combine)
                        Button { instrument.setTempo(instrument.kit.bpm - 5) } label: { Image(systemName: "minus").font(.system(size: 12, weight: .medium)).frame(width: 44, height: 44) }
                            .buttonStyle(PanelKeyStyle(faceHeight: 30, faceWidth: 30))
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Decrease tempo")
                        Button { instrument.setTempo(instrument.kit.bpm + 5) } label: { Image(systemName: "plus").font(.system(size: 12, weight: .medium)).frame(width: 44, height: 44) }
                            .buttonStyle(PanelKeyStyle(faceHeight: 30, faceWidth: 30))
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Increase tempo")
                    }
                }.padding(.leading, 9).padding(.trailing, 7)
                GeometryReader { proxy in
                    let gap: CGFloat = horizontalSizeClass == .regular ? 10 : 6
                    let side = max(1, min(horizontalSizeClass == .regular ? 32 : 22,
                                          (proxy.size.width - gap * 15) / 16))
                    HStack(spacing: gap) {
                        ForEach(0..<16) { step in
                            let hit = instrument.kit.pattern.prefix(instrument.padCapacity).contains { $0[step] }
                            Button { instrument.eraseStep(step) } label: {
                                RoundedRectangle(cornerRadius: Panel.indicatorCornerRadius)
                                    .fill(instrument.currentStep == step ? Panel.ink : hit ? Panel.ink.opacity(0.45) : Panel.paper)
                                    .overlay(RoundedRectangle(cornerRadius: Panel.indicatorCornerRadius)
                                        .stroke(Panel.ink.opacity(step % 4 == 0 ? 0.32 : 0.22), lineWidth: 1))
                                    .frame(width: side, height: side)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Step \(step + 1), \(hit ? "recorded, tap to erase" : "empty")")
                        }
                    }
                }.frame(height: horizontalSizeClass == .regular ? 44 : 32)
                    .padding(.horizontal, 9)
            }.padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: Panel.panelCornerRadius).stroke(Panel.border))
        }.padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 12)
    }

    private func chip(_ text: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(text).font(Panel.mono(9, .semibold)).tracking(0.7).frame(width: 40, height: 44) }
            .buttonStyle(PanelKeyStyle(faceHeight: 30))
            .accessibilityLabel(label)
    }
}

struct PadTile: View {
    let pad: Pad?
    let number: Int
    let selected: Bool
    let flashing: Bool
    let action: () -> Void
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Panel.padCornerRadius).fill(flashing ? Panel.ink : Panel.paper)
            VStack(spacing: 0) {
                ZStack {
                    PadArtwork(pad: pad)
                        .opacity(flashing ? 0.2 : 1)
                    if pad == nil {
                        Text("EMPTY").font(Panel.mono(8)).tracking(1).foregroundStyle(Panel.muted)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: 4) {
                    Circle().fill(pad?.features.ink.color ?? .clear).frame(width: 5, height: 5)
                    Text("P\(number)").font(Panel.mono(8, .medium))
                    Spacer(minLength: 0)
                    Text(pad?.features.ink.tag ?? "—").font(Panel.mono(7))
                        .lineLimit(1).minimumScaleFactor(0.6)
                }.padding(.horizontal, 8).frame(height: Panel.padLabelHeight)
                    .background(flashing ? Panel.ink : Panel.chassis.opacity(0.92))
                    .foregroundStyle(flashing ? Panel.paper : Panel.ink)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            PadTouchSurface(label: "Pad \(number), \(pad?.features.ink.timbre ?? "empty")\(selected ? ", selected" : "")", action: action)
                .accessibilityIdentifier("pad\(number)")
        }
        .clipShape(RoundedRectangle(cornerRadius: Panel.padCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Panel.padCornerRadius).stroke(selected ? Panel.ink : Panel.border, lineWidth: selected ? 2 : 1))
    }
}

struct PadArtwork: View {
    let pad: Pad?
    struct Dot: Equatable {
        var gray: Double = 20.0 / 255
        var opacity: Double = 0
    }
    @State private var cells = Array(repeating: Dot(), count: 169)
    var body: some View {
        Canvas { context, size in
            let insetX = size.width * 0.04
            let insetY = size.height * 0.04
            let fieldWidth = size.width - insetX * 2
            let fieldHeight = size.height - insetY * 2
            let cellWidth = fieldWidth / 13
            let cellHeight = fieldHeight / 13
            let dotSide = min(cellWidth, cellHeight) * 0.48
            let stepX = (fieldWidth - dotSide) / 12
            let stepY = (fieldHeight - dotSide) / 12
            for row in 0..<13 {
                for column in 0..<13 {
                    let dot = cells[row * 13 + column]
                    let rect = CGRect(x: insetX + Double(column) * stepX,
                                      y: insetY + Double(row) * stepY,
                                      width: dotSide, height: dotSide)
                    let color = dot.opacity > 0
                        ? Color(red: dot.gray, green: dot.gray, blue: dot.gray).opacity(dot.opacity)
                        : Panel.ink.opacity(0.055)
                    context.fill(Path(roundedRect: rect, cornerRadius: dotSide * 0.32), with: .color(color))
                }
            }
        }.task(id: pad?.id) { cells = Self.pixelate(pad?.strokes ?? []) }
    }
    static func pixelate(_ strokes: [Stroke]) -> [Dot] {
        // Match app.js makeThumb: ink-length-ranked grays and coverage-based alpha.
        // Keep the native preview's full-pad mapping instead of square letterboxing.
        let size = 200
        let count = 13
        var lengths: [Ink: Double] = [:]
        var inkOrder: [Ink] = []
        for stroke in strokes where !stroke.points.isEmpty {
            if lengths[stroke.ink] == nil { inkOrder.append(stroke.ink) }
            lengths[stroke.ink, default: 0] += zip(stroke.points, stroke.points.dropFirst())
                .reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        }
        let colors = inkOrder.sorted {
            let a = lengths[$0, default: 0], b = lengths[$1, default: 0]
            return a == b ? inkOrder.firstIndex(of: $0)! < inkOrder.firstIndex(of: $1)! : a > b
        }
        let ramp = colors.indices.map { index in
            (20 + (colors.count > 1 ? (Double(index) * 135 / Double(colors.count - 1)).rounded() : 0)) / 255
        }
        // Rasterize round strokes into an ink-index buffer. Later strokes cover earlier
        // ones, as in the web thumbnail's source-over offscreen canvas.
        var pixels = Array(repeating: -1, count: size * size)
        let radius = Double(size) / 27 / 2
        for stroke in strokes {
            guard let first = stroke.points.first, let inkIndex = colors.firstIndex(of: stroke.ink) else { continue }
            let points = stroke.points.count == 1 ? [first, first] : stroke.points
            for (a, b) in zip(points, points.dropFirst()) {
                let ax = a.x * Double(size), ay = a.y * Double(size)
                let bx = b.x * Double(size), by = b.y * Double(size)
                let dx = bx - ax, dy = by - ay
                let lengthSquared = dx * dx + dy * dy
                let x0 = max(0, Int(floor(min(ax, bx) - radius)))
                let x1 = min(size - 1, Int(ceil(max(ax, bx) + radius)))
                let y0 = max(0, Int(floor(min(ay, by) - radius)))
                let y1 = min(size - 1, Int(ceil(max(ay, by) + radius)))
                guard x0 <= x1, y0 <= y1 else { continue }
                for y in y0...y1 {
                    for x in x0...x1 {
                        let px = Double(x) + 0.5, py = Double(y) + 0.5
                        let t = lengthSquared > 0 ? min(1, max(0, ((px - ax) * dx + (py - ay) * dy) / lengthSquared)) : 0
                        if hypot(px - (ax + t * dx), py - (ay + t * dy)) <= radius {
                            pixels[y * size + x] = inkIndex
                        }
                    }
                }
            }
        }
        var cells = Array(repeating: Dot(), count: count * count)
        for row in 0..<count {
            for column in 0..<count {
                var tally = Array(repeating: 0, count: colors.count)
                var inked = 0, total = 0
                for y in stride(from: row * size / count, to: (row + 1) * size / count, by: 2) {
                    for x in stride(from: column * size / count, to: (column + 1) * size / count, by: 2) {
                        total += 1
                        let ink = pixels[y * size + x]
                        if ink >= 0 { inked += 1; tally[ink] += 1 }
                    }
                }
                let coverage = Double(inked) / Double(max(1, total))
                guard coverage >= 0.08, let dominant = tally.indices.max(by: { tally[$0] < tally[$1] }) else { continue }
                cells[row * count + column] = Dot(gray: ramp[dominant], opacity: 0.6 + 0.4 * min(1, coverage * 1.6))
            }
        }
        return cells
    }
}

private struct AIConsentPanel: View {
    @ObservedObject var instrument: Instrument
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var headingFocused: Bool
    @ScaledMetric(relativeTo: .headline) private var headingSize = 13.0
    @ScaledMetric(relativeTo: .footnote) private var bodySize = 11.0
    @ScaledMetric(relativeTo: .caption) private var keySize = 10.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Panel.ink.opacity(0.24)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ViewThatFits(in: .vertical) {
                    panel(scrolls: false).fixedSize(horizontal: false, vertical: true)
                    panel(scrolls: true)
                }
                .frame(maxWidth: 400)
                .background(Panel.paper)
                .clipShape(RoundedRectangle(cornerRadius: Panel.panelCornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Panel.panelCornerRadius).stroke(Panel.border, lineWidth: 1))
                .padding(16)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityIdentifier("aiConsentPanel")
                .accessibilityAction(.escape) { instrument.showAIConsent = false }
            }
        }
        .onAppear { headingFocused = true }
    }

    private func panel(scrolls: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: Panel.logoCornerRadius).fill(Panel.ink).frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text("GENERATE WITH AI?")
                    .font(Panel.mono(headingSize, .semibold)).tracking(0.5)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Panel.border).frame(height: 1)
            if scrolls {
                ScrollView { disclosure }
                    .scrollBounceBehavior(.basedOnSize)
                    .clipped()
            } else {
                disclosure
            }
            actions
                .padding(.top, scrolls ? 14 : 0)
                .padding([.horizontal, .bottom], 14)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Panel.ink)
    }

    private var disclosure: some View {
        Text("A sound description and duration will be sent to Tink-on’s server and ElevenLabs. Drawing pixels stay on this device. The server may log your IP address; ElevenLabs may retain prompts and audio for service operation and model improvement. You can switch to SYNTH in Settings at any time.")
            .font(Panel.mono(bodySize))
            .foregroundStyle(Panel.muted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
    }

    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button {
                instrument.showAIConsent = false
                instrument.useSynthAndGenerate()
            } label: {
                keyLabel("USE OFFLINE SYNTH")
            }
            .buttonStyle(PanelKeyStyle(faceHeight: max(30, keySize * 1.2 + 16)))
            .accessibilityLabel("Use Offline Synth")
            Button {
                instrument.showAIConsent = false
                instrument.allowAIAndGenerate()
            } label: {
                keyLabel("USE AI")
            }
            .buttonStyle(PanelKeyStyle(prominent: true, faceHeight: max(30, keySize * 1.2 + 16)))
            .accessibilityLabel("Use AI")
        }
    }

    private func keyLabel(_ title: String) -> some View {
        Text(title).font(Panel.mono(keySize, .semibold)).tracking(0.5)
            .padding(.horizontal, 8).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct SettingsView: View {
    @ObservedObject var instrument: Instrument
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .footnote) private var bodySize = 11.0
    @ScaledMetric(relativeTo: .caption) private var keySize = 10.0
    @ScaledMetric(relativeTo: .caption) private var labelSize = 9.0
    @ScaledMetric(relativeTo: .caption2) private var detailSize = 8.0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                Rectangle().fill(Panel.border).frame(height: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if geometry.size.width >= 600 && !dynamicTypeSize.isAccessibilitySize {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 12) { guide; savedKit; information }
                                    .frame(maxWidth: .infinity)
                                VStack(spacing: 12) { soundSource; inkVoices }
                                    .frame(maxWidth: .infinity)
                            }
                        } else {
                            soundSource
                            guide
                            inkVoices
                            savedKit
                            information
                        }
                        HStack {
                            Text("TINK-ON / \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            Spacer()
                            Text("SKETCH · SOUND · PLAY")
                        }
                        .font(Panel.mono(detailSize)).tracking(1).foregroundStyle(Panel.muted)
                    }.padding(14)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Panel.chassis)
        .foregroundStyle(Panel.ink)
        .tint(Panel.ink)
    }

    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: Panel.logoCornerRadius).fill(Panel.ink).frame(width: 9, height: 9)
            Text("TINK-ON").font(Panel.mono(13, .bold)).tracking(2)
            Text("SETTINGS").font(Panel.mono(9)).tracking(1).foregroundStyle(Panel.muted)
            Spacer()
            Button { dismiss() } label: {
                Text("DONE").font(Panel.mono(keySize, .semibold)).tracking(0.5)
                    .padding(.horizontal, 8).padding(.vertical, 8)
                    .frame(minWidth: 66, minHeight: 44)
            }
            .buttonStyle(PanelKeyStyle(faceHeight: max(30, keySize * 1.2 + 16)))
            .accessibilityLabel("Close settings")
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private var guide: some View {
        section("PLAY GUIDE", detail: "01—03") {
            instruction("01", title: "DRAW", text: "Choose an ink and sketch. Height sets pitch, length sets duration, and speed and corners shape the texture.")
            divider
            instruction("02", title: "GENERATE", text: "Turn your drawing into a sound. Tap its pad to play, then adjust the pitch.")
            divider
            instruction("03", title: "MAKE A BEAT", text: "Press PLAY and tap pads to record a repeating 16-step beat. Tap a filled step to erase its hits.")
        }
    }

    private var soundSource: some View {
        section("SOUND SOURCE", detail: instrument.kit.aiEnabled ? "AI + LOCAL" : "LOCAL") {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                sourceKey("SYNTH", ai: false)
                sourceKey("AI + SYNTH", ai: true)
            }
            Text("SYNTH works offline. AI + SYNTH uses ElevenLabs to generate a sound, with the local synth as a fallback.")
                .font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
            divider
            Text("AI + SYNTH is selected for new installs. Before the first AI request, GENERATE asks permission to send a derived sound description and duration to Tink-on’s server and ElevenLabs. Your drawing pixels stay on this device. Select SYNTH to use only offline generation.")
                .font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
            Text("ElevenLabs may retain requests and generated audio and use them to improve its models. See the privacy policy below.")
                .font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
            Text("AI needs internet and may be unavailable when service credits run out. Saved pads, sequencing and WAV export still work offline.")
                .font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
        }
    }

    private func sourceKey(_ title: String, ai: Bool) -> some View {
        Button { instrument.setAI(ai) } label: {
            Text(title).font(Panel.mono(keySize, .semibold)).tracking(0.5)
                .padding(.horizontal, 8).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(PanelKeyStyle(prominent: instrument.kit.aiEnabled == ai, faceHeight: max(30, keySize * 1.2 + 16)))
        .accessibilityLabel(ai ? "Enable optional AI generation" : "Use offline synth")
        .accessibilityValue(instrument.kit.aiEnabled == ai ? "Selected" : "Not selected")
    }

    private var inkVoices: some View {
        section("INK VOICES", detail: "04 INKS") {
            ForEach(Ink.allCases) { ink in
                HStack(spacing: 10) {
                    Circle().fill(ink.color).frame(width: 14, height: 14)
                    Text(ink.tag).font(Panel.mono(labelSize, .semibold)).frame(minWidth: 52, alignment: .leading)
                    Text(ink.timbre).font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
                    Spacer(minLength: 0)
                }.padding(.vertical, 2)
            }
        }
    }

    private var savedKit: some View {
        section("YOUR KIT", detail: "AUTO SAVE") {
            Text("Your sketch, pads, pitch and beat save automatically on this device. Select a pad and use the share button to export a WAV.")
                .font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
            divider
            Text("No sign-in, ads, analytics or microphone access.")
                .font(Panel.mono(keySize)).foregroundStyle(Panel.muted)
        }
    }

    private var information: some View {
        section("SUPPORT & PRIVACY", detail: "TINK-ON") {
            informationLink("PLAY GUIDE & SUPPORT", url: "https://tinkon.zui.ooo/support.html")
            divider
            informationLink("TINK-ON PRIVACY POLICY", url: "https://tinkon.zui.ooo/privacy.html")
        }
    }

    private func informationLink(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 6) {
                Text(title).font(Panel.mono(labelSize, .medium)).tracking(0.4)
                Image(systemName: "arrow.up.right").font(.system(size: 10))
            }.frame(minHeight: 44, alignment: .leading)
        }.buttonStyle(.plain)
    }

    private var divider: some View { Rectangle().fill(Panel.border).frame(height: 1) }

    private func instruction(_ number: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number).font(Panel.mono(keySize)).foregroundStyle(Panel.muted).padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(Panel.mono(keySize, .semibold)).tracking(0.7)
                Text(text).font(Panel.mono(bodySize)).foregroundStyle(Panel.muted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Panel.mono(labelSize, .semibold)).tracking(1)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail).font(Panel.mono(detailSize)).foregroundStyle(Panel.muted)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(Panel.mono(labelSize, .semibold)).tracking(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 4)
                    Text(detail).font(Panel.mono(detailSize)).foregroundStyle(Panel.muted)
                }
            }
            divider
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Panel.paper)
        .clipShape(RoundedRectangle(cornerRadius: Panel.panelCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Panel.panelCornerRadius).stroke(Panel.border, lineWidth: 1))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
