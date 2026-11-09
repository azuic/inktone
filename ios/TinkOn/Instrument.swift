import SwiftUI
import AVFoundation

struct SharedAudio: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class Instrument: ObservableObject {
    let padCapacity: Int
    @Published var kit = Kit()
    @Published var message = "draw, then press GENERATE"
    @Published var generating = false
    @Published var playing = false
    @Published var currentStep = -1
    @Published var flashes: Set<Int> = []
    @Published var sharedAudio: SharedAudio?
    @Published var showAIConsent = false
    private let audio = InstrumentAudio()
    private let storage: KitStorage?
    private var saveTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?
    private var flashTasks: [Int: Task<Void, Never>] = [:]
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    private var observers: [NSObjectProtocol] = []

    init(padCapacity: Int = 8) {
        self.padCapacity = padCapacity
        do {
            let storage = try KitStorage()
            self.storage = storage
            do { kit = try storage.load() }
            catch {
                let previous = storage.directory.appendingPathComponent("kit.json")
                let recovery = storage.directory.appendingPathComponent("kit-recovery-\(UUID().uuidString).json")
                try? FileManager.default.copyItem(at: previous, to: recovery)
                message = "Saved kit could not be opened. A recovery copy is on this device."
            }
        } catch {
            storage = nil
            message = "Device storage unavailable — this session cannot be saved"
        }
        // Retain the full saved kit, but expose and play only this device's bank.
        if !(0..<padCapacity).contains(kit.selected) {
            kit.selected = kit.pads.prefix(padCapacity).firstIndex { $0 != nil } ?? -1
        }
        audio.onStep = { [weak self] step, slots in
            guard let self, self.playing else { return }
            self.currentStep = step
            slots.forEach { self.flash($0) }
        }
        audio.onRecorded = { [weak self] slot, step in
            guard let self else { return }
            self.kit.pattern[slot][step] = true
            self.persist()
        }
        audio.onError = { [weak self] message in
            self?.message = message
            self?.playing = false
            self?.currentStep = -1
        }
        if let storage {
            for slot in 0..<padCapacity { audio.install(kit.pads[slot], at: slot, directory: storage.directory) }
        }
        audio.update(pattern: visiblePattern, bpm: kit.bpm)
        feedback.prepare()
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            let token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == AVAudioSession.interruptionNotification {
                    guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                }
                if name == AVAudioSession.routeChangeNotification {
                    guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                          AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
                }
                Task { @MainActor in self?.pauseForSystemEvent() }
            }
            observers.append(token)
        }
    }

    func setStrokes(_ strokes: [Stroke]) { kit.strokes = strokes; persist() }
    func selectInk(_ ink: Ink) { kit.ink = ink; feedback.impactOccurred(intensity: 0.4); persist() }
    func setAI(_ enabled: Bool) {
        kit.aiEnabled = enabled
        if !enabled { kit.aiConsentGranted = false }
        persist()
    }
    func allowAIAndGenerate() {
        kit.aiConsentGranted = true
        saveNow()
        generate()
    }
    func useSynthAndGenerate() {
        setAI(false)
        generate()
    }
    func undo() { if !kit.strokes.isEmpty { kit.strokes.removeLast(); persist() } }
    func clearSketch() { kit.strokes = []; persist() }
    func tap(_ slot: Int) {
        guard (0..<padCapacity).contains(slot) else { return }
        kit.selected = slot
        guard kit.pads[slot] != nil else { persist(); return }
        audio.tap(slot)
        feedback.impactOccurred(intensity: 0.55)
        feedback.prepare()
        flash(slot)
        persist()
    }
    private func flash(_ slot: Int) {
        flashes.insert(slot)
        flashTasks[slot]?.cancel()
        flashTasks[slot] = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            flashes.remove(slot)
        }
    }
    private var visiblePattern: [[Bool]] { Array(kit.pattern.prefix(padCapacity)) }
    var selectedPad: Pad? { (0..<padCapacity).contains(kit.selected) ? kit.pads[kit.selected] : nil }
    func setPitch(_ value: Double) {
        guard selectedPad != nil else { return }
        let pitch = Int(value.rounded())
        guard kit.pads[kit.selected]?.pitch != pitch else { return }
        kit.pads[kit.selected]?.pitch = pitch
        audio.pitch(pitch, slot: kit.selected)
        persist()
    }
    func deletePad() {
        guard selectedPad != nil, let storage else { return }
        let file = selectedPad?.audioFile
        kit.pads[kit.selected] = nil
        kit.pattern[kit.selected] = Array(repeating: false, count: 16)
        audio.install(nil, at: kit.selected, directory: storage.directory)
        audio.update(pattern: visiblePattern, bpm: kit.bpm)
        saveNow()
        if let file { try? FileManager.default.removeItem(at: storage.directory.appendingPathComponent(file)) }
        message = "slot cleared"
    }
    func toggleTransport() {
        if playing { stop() }
        else { playing = true; audio.update(pattern: visiblePattern, bpm: kit.bpm); audio.start() }
    }
    func stop() { playing = false; currentStep = -1; audio.stop() }
    func setTempo(_ bpm: Int) {
        kit.bpm = min(240, max(40, bpm))
        audio.update(pattern: visiblePattern, bpm: kit.bpm)
        persist()
    }
    func eraseStep(_ step: Int) {
        for slot in 0..<padCapacity { kit.pattern[slot][step] = false }
        audio.update(pattern: visiblePattern, bpm: kit.bpm)
        persist()
    }
    func generate() {
        guard !generating else { return }
        guard let features = SoundFeatures.analyze(kit.strokes) else { message = "nothing sketched — draw first"; return }
        guard let storage else { message = "Device storage unavailable"; return }
        if kit.aiEnabled && !kit.aiConsentGranted {
            showAIConsent = true
            return
        }
        let sketch = kit.strokes
        let useAI = kit.aiEnabled
        let slot = kit.pads.prefix(padCapacity).firstIndex(where: { $0 == nil })
            ?? min(padCapacity - 1, max(0, kit.selected))
        generating = true
        message = useAI ? "generating with AI…" : "rendering your sketch…"
        generationTask = Task {
            var pad = Pad(features: features, strokes: sketch)
            var fallback = false
            if useAI {
                do {
                    guard let value = Bundle.main.object(forInfoDictionaryKey: "TinkOnSoundEndpoint") as? String,
                          let endpoint = URL(string: value) else { throw URLError(.badURL) }
                    pad.audioFile = try await SoundService(endpoint: endpoint).generate(features, directory: storage.directory)
                } catch {
                    fallback = true
                }
            }
            guard !Task.isCancelled else {
                if let file = pad.audioFile { try? FileManager.default.removeItem(at: storage.directory.appendingPathComponent(file)) }
                generating = false
                return
            }
            let oldFile = kit.pads[slot]?.audioFile
            kit.pads[slot] = pad
            kit.selected = slot
            // Keep any new drawing made before the rendering task runs.
            let captured = Set(sketch.map(\.id))
            kit.strokes.removeAll { captured.contains($0.id) }
            audio.install(pad, at: slot, directory: storage.directory)
            generating = false
            message = fallback ? "AI unavailable — local synth · \(pad.prompt)" : pad.prompt
            saveNow()
            if let oldFile { try? FileManager.default.removeItem(at: storage.directory.appendingPathComponent(oldFile)) }
            tap(slot)
        }
    }

    func sharePad() {
        guard selectedPad != nil else { return }
        audio.export(slot: kit.selected) { [weak self] result in
            switch result {
            case .success(let url): self?.sharedAudio = SharedAudio(url: url)
            case .failure: self?.message = "Audio could not be exported. Try again."
            }
        }
    }
    func persist() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }
    func saveNow() {
        saveTask?.cancel()
        guard let storage else { return }
        do { try storage.save(kit) }
        catch { message = "Kit could not be saved. Free up device storage and try again." }
    }
    func pauseForSystemEvent() {
        if generating {
            generationTask?.cancel()
            message = "generation paused — press GENERATE again"
        }
        playing = false
        currentStep = -1
        audio.suspend()
        saveNow()
    }
}
