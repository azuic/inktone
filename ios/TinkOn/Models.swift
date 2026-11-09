import Foundation

enum Ink: String, Codable, CaseIterable, Identifiable {
    case blue, yellow, orange, pink
    var id: String { rawValue }
    var tag: String {
        switch self { case .blue: return "TONE"; case .yellow: return "TEXTR"; case .orange: return "IMPACT"; case .pink: return "SUB" }
    }
    var timbre: String {
        switch self {
        case .blue: return "resonant tone"
        case .yellow: return "grainy texture"
        case .orange: return "metallic impact"
        case .pink: return "deep sub drone"
        }
    }
}

// Coordinates are normalized, so sketches survive rotation and kit restoration.
struct SketchPoint: Codable, Equatable {
    var x: Double
    var y: Double
    var time: Double
}

struct Stroke: Codable, Identifiable, Equatable {
    var id = UUID()
    var ink: Ink
    var points: [SketchPoint]
}

struct SoundFeatures: Codable, Equatable {
    var ink: Ink
    var frequency: Double
    var duration: Double
    var grit: Double
    var flutter: Double
    var speed: Double
    var brightness: Double

    static func analyze(_ strokes: [Stroke]) -> SoundFeatures? {
        var lengths: [Ink: Double] = [:]
        var total = 0.0, height = 0.0, speed = 0.0, jaggedness = 0.0
        var segments = 0, turns = 0
        // A stable virtual paper size keeps the sound independent of device size.
        let paper = 320.0
        for stroke in strokes where !stroke.points.isEmpty {
            lengths[stroke.ink, default: 0] += 0.001
            let points = stroke.points
            guard points.count > 1 else { continue }
            for i in 1..<points.count {
                let p = points[i], previous = points[i - 1]
                let dx = (p.x - previous.x) * paper, dy = (p.y - previous.y) * paper
                let length = hypot(dx, dy)
                total += length
                lengths[stroke.ink, default: 0] += length
                height += min(1, max(0, p.y))
                speed += length / max(1, (p.time - previous.time) * 1000)
                segments += 1
                if i > 1 {
                    let before = points[i - 2]
                    let a = atan2(previous.y - before.y, previous.x - before.x)
                    let b = atan2(p.y - previous.y, p.x - previous.x)
                    let delta = abs(b - a)
                    jaggedness += min(delta, 2 * .pi - delta)
                    turns += 1
                }
            }
        }
        guard let ink = Ink.allCases.max(by: { lengths[$0, default: 0] < lengths[$1, default: 0] }), lengths[ink] != nil else { return nil }
        let brightness = segments > 0 ? 1 - height / Double(segments) : 0.5
        let meanSpeed = speed / Double(max(1, segments))
        return SoundFeatures(ink: ink, frequency: 80 + pow(brightness, 1.6) * 800,
                             duration: min(1.6, 0.25 + total / 900),
                             grit: min(1, jaggedness / Double(max(1, turns)) / 0.9),
                             flutter: min(12, 1 + meanSpeed * 8), speed: meanSpeed, brightness: brightness)
    }

    var prompt: String {
        let movement = speed > 1.1 ? "fluttering" : speed < 0.35 ? "slow-moving" : "steady"
        let texture = grit > 0.5 ? "jagged, gritty" : "smooth, rounded"
        let tone = brightness > 0.6 ? "bright, airy" : brightness < 0.35 ? "dark, weighty" : "warm"
        return "\(movement) \(texture) \(ink.timbre), \(tone) character, \(String(format: "%.1f", duration))s"
    }
}

struct Pad: Codable, Identifiable {
    var id = UUID()
    var features: SoundFeatures
    var strokes: [Stroke]
    var pitch = 0
    var audioFile: String?
    var prompt: String { features.prompt }
}

struct Kit: Codable {
    static let slotCount = 12
    var version = 2
    var pads: [Pad?] = Array(repeating: nil, count: Kit.slotCount)
    var strokes: [Stroke] = []
    var pattern: [[Bool]] = Array(repeating: Array(repeating: false, count: 16), count: Kit.slotCount)
    var bpm = 120
    var selected = -1
    var ink: Ink = .blue
    var aiEnabled = true
    var aiConsentGranted = false

    init() {}
    private enum CodingKeys: String, CodingKey {
        case version, pads, strokes, pattern, bpm, selected, ink, aiEnabled, aiConsentGranted
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        pads = try values.decode([Pad?].self, forKey: .pads)
        strokes = try values.decode([Stroke].self, forKey: .strokes)
        pattern = try values.decode([[Bool]].self, forKey: .pattern)
        bpm = try values.decode(Int.self, forKey: .bpm)
        selected = try values.decode(Int.self, forKey: .selected)
        ink = try values.decode(Ink.self, forKey: .ink)
        // Expand the original eight-slot kit without changing its sounds or beat.
        if version == 1 && pads.count == 8 && pattern.count == 8 && (-1..<8).contains(selected) {
            pads += Array(repeating: nil, count: Self.slotCount - 8)
            pattern += Array(repeating: Array(repeating: false, count: 16), count: Self.slotCount - 8)
            version = 2
        }
        // Build 7 saved local-only kits without a sound-source preference.
        aiEnabled = try values.decodeIfPresent(Bool.self, forKey: .aiEnabled) ?? false
        aiConsentGranted = try values.decodeIfPresent(Bool.self, forKey: .aiConsentGranted) ?? false
    }

    var isValid: Bool {
        version == 2 && pads.count == Self.slotCount && pattern.count == Self.slotCount && pattern.allSatisfy { $0.count == 16 }
        && (40...240).contains(bpm) && (-1..<Self.slotCount).contains(selected)
        && pads.compactMap { $0 }.allSatisfy {
            (-12...12).contains($0.pitch) && $0.features.frequency.isFinite && (35...2000).contains($0.features.frequency)
            && $0.features.duration.isFinite && (0.25...1.6).contains($0.features.duration)
            && ($0.audioFile == nil || $0.audioFile == URL(fileURLWithPath: $0.audioFile!).lastPathComponent)
        }
    }
}

struct KitStorage {
    let directory: URL
    init(directory: URL? = nil) throws {
        self.directory = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("TinkOn", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }
    func load() throws -> Kit {
        let url = directory.appendingPathComponent("kit.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return Kit() }
        let kit = try JSONDecoder().decode(Kit.self, from: Data(contentsOf: url))
        guard kit.isValid else { throw CocoaError(.fileReadCorruptFile) }
        return kit
    }
    func save(_ kit: Kit) throws {
        try JSONEncoder().encode(kit).write(to: directory.appendingPathComponent("kit.json"), options: .atomic)
    }
}
