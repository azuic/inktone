// Run alongside Models.swift to create local simulator presentation data.
// This kit is never bundled with the shipping app.
import Foundation

func line(_ ink: Ink, points: [(Double, Double)]) -> Stroke {
    Stroke(ink: ink, points: points.enumerated().map {
        SketchPoint(x: $0.element.0, y: $0.element.1, time: Double($0.offset) * 0.012)
    })
}

// Smooth hand-placed bends, with deliberately uneven turns and overlaps.
// Deterministic presentation data keeps the iPhone/iPad review shots consistent.
func freehand(_ ink: Ink, _ anchors: [(Double, Double)]) -> Stroke {
    var points: [(Double, Double)] = []
    for i in 0..<(anchors.count - 1) {
        let a = anchors[max(0, i - 1)], b = anchors[i]
        let c = anchors[i + 1], d = anchors[min(anchors.count - 1, i + 2)]
        for step in 0..<12 {
            let t = Double(step) / 12, t2 = t * t, t3 = t2 * t
            func value(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
                0.5 * ((2 * b) + (-a + c) * t + (2*a - 5*b + 4*c - d) * t2 + (-a + 3*b - 3*c + d) * t3)
            }
            points.append((value(a.0, b.0, c.0, d.0), value(a.1, b.1, c.1, d.1)))
        }
    }
    points.append(anchors.last!)
    return line(ink, points: points)
}

let yellowScribble = freehand(.yellow, [
    (0.33,0.25),(0.31,0.15),(0.48,0.09),(0.72,0.10),(0.83,0.18),
    (0.85,0.28),(0.76,0.33),(0.56,0.32),(0.47,0.25),(0.45,0.16),
    (0.63,0.16),(0.71,0.30),(0.76,0.47),(0.57,0.51),(0.43,0.48),
    (0.42,0.39),(0.57,0.36),(0.68,0.44),(0.68,0.54),(0.53,0.61),
    (0.45,0.60),(0.48,0.56),(0.65,0.60),(0.67,0.67),(0.54,0.73),
    (0.37,0.77),(0.27,0.68),(0.22,0.52),(0.21,0.33)
])
let blueScribble = freehand(.blue, [
    (0.60,0.12),(0.47,0.13),(0.40,0.23),(0.49,0.28),(0.70,0.29),
    (0.57,0.30),(0.44,0.37),(0.43,0.44),(0.49,0.50),(0.58,0.49),
    (0.43,0.51),(0.28,0.60),(0.18,0.69),(0.31,0.73),(0.48,0.65),
    (0.32,0.65),(0.29,0.73),(0.43,0.84),(0.57,0.87),(0.66,0.86)
])
let sketches: [[Stroke]] = [
    [blueScribble],
    [yellowScribble],
    [yellowScribble, blueScribble],
    [freehand(.pink, [(0.25,0.25),(0.62,0.16),(0.79,0.35),(0.65,0.61),(0.32,0.72),(0.23,0.56),(0.45,0.37),(0.71,0.42),(0.58,0.78)])],
    [freehand(.blue, [(0.18,0.30),(0.35,0.23),(0.62,0.39),(0.75,0.31),(0.70,0.51),(0.44,0.62),(0.23,0.55),(0.35,0.78),(0.70,0.72)])],
    [freehand(.yellow, [(0.21,0.23),(0.68,0.18),(0.76,0.35),(0.52,0.49),(0.31,0.41),(0.28,0.60),(0.63,0.75),(0.78,0.62)])],
    [freehand(.orange, [(0.19,0.75),(0.30,0.36),(0.44,0.22),(0.52,0.64),(0.69,0.35),(0.81,0.55)]), freehand(.pink, [(0.23,0.57),(0.52,0.44),(0.74,0.68)])],
    [freehand(.pink, [(0.34,0.19),(0.72,0.29),(0.78,0.60),(0.50,0.79),(0.21,0.63),(0.28,0.37),(0.59,0.31),(0.65,0.55),(0.43,0.64),(0.39,0.46)])],
    [freehand(.blue, [(0.16,0.65),(0.26,0.31),(0.43,0.19),(0.61,0.38),(0.47,0.55),(0.31,0.60),(0.53,0.78),(0.81,0.56)])],
    [freehand(.yellow, [(0.20,0.66),(0.28,0.21),(0.50,0.18),(0.73,0.40),(0.53,0.64),(0.35,0.40),(0.63,0.29),(0.81,0.76)])],
    [freehand(.orange, [(0.16,0.68),(0.32,0.25),(0.46,0.59),(0.61,0.20),(0.80,0.66)])],
    [freehand(.pink, [(0.20,0.25),(0.52,0.16),(0.79,0.34),(0.75,0.62),(0.46,0.80),(0.22,0.61),(0.37,0.36),(0.63,0.42),(0.53,0.64)])]
]
var presentationKit = Kit()
presentationKit.pads = sketches.enumerated().map { index, strokes in
    var pad = Pad(features: SoundFeatures.analyze(strokes)!, strokes: strokes)
    pad.pitch = index == 2 ? 7 : index == 7 ? -5 : 0
    return pad
}
presentationKit.strokes = [yellowScribble, blueScribble]
presentationKit.aiEnabled = false
presentationKit.ink = .blue
presentationKit.selected = 2
for step in [0,4,8] { presentationKit.pattern[0][step] = true }
for step in [1,9] { presentationKit.pattern[1][step] = true }
precondition(presentationKit.isValid)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try encoder.encode(presentationKit).write(to: output, options: .atomic)
