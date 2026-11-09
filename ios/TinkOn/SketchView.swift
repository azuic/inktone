import SwiftUI
import UIKit

extension Ink {
    var uiColor: UIColor {
        switch self {
        case .blue: return UIColor(red: 47/255, green: 168/255, blue: 222/255, alpha: 1)
        case .yellow: return UIColor(red: 244/255, green: 194/255, blue: 13/255, alpha: 1)
        case .orange: return UIColor(red: 241/255, green: 90/255, blue: 43/255, alpha: 1)
        case .pink: return UIColor(red: 240/255, green: 80/255, blue: 158/255, alpha: 1)
        }
    }
    var color: Color { Color(uiColor: uiColor) }
}

struct SketchView: UIViewRepresentable {
    let strokes: [Stroke]
    let ink: Ink
    let onCommit: (Stroke) -> Void
    func makeUIView(context: Context) -> DrawingSurface { DrawingSurface() }
    func updateUIView(_ view: DrawingSurface, context: Context) {
        if view.strokes != strokes { view.strokes = strokes; view.setNeedsDisplay() }
        view.ink = ink
        view.onCommit = onCommit
    }
}

final class DrawingSurface: UIView {
    var strokes: [Stroke] = []
    var ink: Ink = .blue
    var onCommit: ((Stroke) -> Void)?
    private var active: Stroke?
    private weak var activeTouch: UITouch?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        isMultipleTouchEnabled = false
        backgroundColor = UIColor(white: 0.96, alpha: 1)
        accessibilityLabel = "Sketch paper"
        accessibilityHint = "Draw with your finger or Apple Pencil, then choose Generate"
        isAccessibilityElement = true
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func point(_ touch: UITouch) -> SketchPoint {
        let p = touch.location(in: self)
        return SketchPoint(x: min(1, max(0, p.x / max(1, bounds.width))),
                           y: min(1, max(0, p.y / max(1, bounds.height))), time: touch.timestamp)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active == nil, let touch = touches.first else { return }
        activeTouch = touch
        active = Stroke(ink: ink, points: [point(touch)])
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), active != nil else { return }
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            let p = point(sample)
            if let last = active?.points.last, hypot(p.x - last.x, p.y - last.y) < 0.003 { continue }
            active?.points.append(p)
        }
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), var stroke = active else { return }
        stroke.points.append(point(touch))
        strokes.append(stroke)
        active = nil
        activeTouch = nil
        onCommit?(stroke)
        setNeedsDisplay()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        active = nil
        activeTouch = nil
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(UIColor(red: 244/255, green: 245/255, blue: 247/255, alpha: 1).cgColor)
        context.fill(bounds)
        context.setFillColor(UIColor(red: 196/255, green: 200/255, blue: 207/255, alpha: 1).cgColor)
        let spacing: CGFloat = 18
        let columns = max(1, Int((bounds.width - 24) / spacing) + 1)
        let rows = max(1, Int((bounds.height - 24) / spacing) + 1)
        let startX = (bounds.width - CGFloat(columns - 1) * spacing) / 2
        let startY = (bounds.height - CGFloat(rows - 1) * spacing) / 2
        for column in 0..<columns {
            for row in 0..<rows {
                context.fill(CGRect(x: startX + CGFloat(column) * spacing - 0.75,
                                    y: startY + CGFloat(row) * spacing - 0.75,
                                    width: 1.5, height: 1.5))
            }
        }
        for stroke in strokes + (active.map { [$0] } ?? []) {
            guard let first = stroke.points.first else { continue }
            context.setBlendMode(.multiply)
            context.setAlpha(0.92)
            context.setStrokeColor(stroke.ink.uiColor.cgColor)
            context.setFillColor(stroke.ink.uiColor.cgColor)
            context.setLineWidth(max(6, min(bounds.width, bounds.height) / 27))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            let start = CGPoint(x: first.x * bounds.width, y: first.y * bounds.height)
            if stroke.points.count == 1 || stroke.points.allSatisfy({ $0.x == first.x && $0.y == first.y }) {
                let radius = max(6, min(bounds.width, bounds.height) / 27) / 2
                context.fillEllipse(in: CGRect(x: start.x - radius, y: start.y - radius, width: radius * 2, height: radius * 2))
            } else {
                context.beginPath()
                context.move(to: start)
                for p in stroke.points.dropFirst() { context.addLine(to: CGPoint(x: p.x * bounds.width, y: p.y * bounds.height)) }
                context.strokePath()
            }
        }
    }
}

// UIKit receives each pad's touch-down independently, allowing simultaneous
// fingers on different pads without waiting for a SwiftUI tap gesture to end.
struct PadTouchSurface: UIViewRepresentable {
    let label: String
    let action: () -> Void
    func makeUIView(context: Context) -> ImmediatePad { ImmediatePad() }
    func updateUIView(_ view: ImmediatePad, context: Context) { view.action = action; view.accessibilityLabel = label }
}
final class ImmediatePad: UIControl {
    var action: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { action?(); return true }
    override func accessibilityActivate() -> Bool { action?(); return true }
}
