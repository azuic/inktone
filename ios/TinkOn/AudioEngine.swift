import AVFoundation

enum SampleRenderer {
    static let sampleRate = 48_000.0
    static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    static func synthesize(_ f: SoundFeatures) -> AVAudioPCMBuffer {
        let count = Int(f.duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = buffer.frameCapacity
        let output = buffer.floatChannelData![0]
        var phase = 0.0, secondPhase = 0.0, noiseState: UInt64 = 0x12345678
        var smoothNoise = 0.0, low = 0.0, band = 0.0
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1, t / (f.ink == .orange ? 0.002 : 0.025))
            let release = min(1, max(0, (f.duration - t) / 0.04))
            noiseState = noiseState &* 6364136223846793005 &+ 1
            let noise = Double(noiseState >> 32) / Double(UInt32.max) * 2 - 1
            let flutter = sin(2 * .pi * f.flutter * t)
            var frequency = f.frequency
            if f.ink == .pink { frequency = max(35, frequency * 0.5) }
            if f.ink == .orange { frequency *= 0.6 + 5 * exp(-t * 55) }
            frequency *= 1 + flutter * (0.004 + f.grit * 0.012)
            phase += 2 * .pi * frequency / sampleRate
            secondPhase += 2 * .pi * frequency * (1.003 + f.grit * 0.013) / sampleRate
            var value = 0.0
            switch f.ink {
            case .blue:
                value = (asin(sin(phase)) + asin(sin(secondPhase))) / .pi
                value *= 0.65 + 0.35 * exp(-t * 5)
            case .yellow:
                smoothNoise = 0.85 * smoothNoise + 0.15 * noise
                let cutoff = min(6000, f.frequency * (2.5 + flutter))
                let coefficient = 2 * sin(.pi * cutoff / sampleRate)
                low += coefficient * band
                let high = smoothNoise - low - (0.3 + (1 - f.grit) * 0.4) * band
                band += coefficient * high
                value = tanh(band * 4) * (0.7 + 0.3 * flutter)
            case .orange:
                value = sin(phase) * exp(-t * 14) + noise * exp(-t * 35) * 0.35
                value += sin(secondPhase * 2.71) * exp(-t * 10) * (0.15 + f.grit * 0.25)
            case .pink:
                value = (sin(phase) + sin(secondPhase)) * 0.5 * exp(-t / max(0.1, f.duration))
            }
            output[i] = Float(tanh(value * 1.3) * attack * release * 0.65)
        }
        return buffer
    }

    // Resampling gives pitch and duration the same relationship as the web sampler.
    static func pitched(_ source: AVAudioPCMBuffer, semitones: Int) -> AVAudioPCMBuffer {
        guard semitones != 0 else { return source }
        let rate = pow(2.0, Double(semitones) / 12)
        let length = max(1, Int(Double(source.frameLength) / rate))
        let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))!
        result.frameLength = result.frameCapacity
        let input = source.floatChannelData![0], output = result.floatChannelData![0]
        for i in 0..<length {
            let position = Double(i) * rate
            let a = min(Int(source.frameLength) - 1, Int(position))
            let b = min(Int(source.frameLength) - 1, a + 1)
            let fraction = Float(position - Double(a))
            output[i] = input[a] * (1 - fraction) + input[b] * fraction
        }
        return result
    }

    static func read(_ url: URL, duration: Double) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0, file.length <= AVAudioFramePosition(file.processingFormat.sampleRate * 31) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        let chunk = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 16384)!
        var framesRead: AVAudioFrameCount = 0
        // A read can return fewer frames than requested, including a final
        // partial PCM packet. Continue until EOF rather than truncating it.
        while framesRead < source.frameCapacity {
            try file.read(into: chunk, frameCount: min(chunk.frameCapacity, source.frameCapacity - framesRead))
            guard chunk.frameLength > 0 else { break }
            for channel in 0..<Int(file.processingFormat.channelCount) {
                source.floatChannelData![channel].advanced(by: Int(framesRead))
                    .update(from: chunk.floatChannelData![channel], count: Int(chunk.frameLength))
            }
            framesRead += chunk.frameLength
        }
        source.frameLength = framesRead
        let converted: AVAudioPCMBuffer
        if file.processingFormat.sampleRate == sampleRate && file.processingFormat.channelCount == 1
            && file.processingFormat.commonFormat == .pcmFormatFloat32 && !file.processingFormat.isInterleaved {
            // Avoid converter packet rounding when restoring our own PCM clips.
            converted = source
        } else {
            guard let converter = AVAudioConverter(from: file.processingFormat, to: format) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * sampleRate / file.processingFormat.sampleRate)) + 2048
            converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
            var supplied = false
            var error: NSError?
            let status = converter.convert(to: converted, error: &error) { _, inputStatus in
                if supplied { inputStatus.pointee = .endOfStream; return nil }
                supplied = true
                inputStatus.pointee = .haveData
                return source
            }
            if let error { throw error }
            guard status != .error else { throw CocoaError(.fileReadCorruptFile) }
        }
        guard converted.frameLength > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let targetLength = min(converted.frameLength, AVAudioFrameCount(duration * sampleRate))
        if targetLength < converted.frameLength {
            converted.frameLength = targetLength
            let fade = min(Int(converted.frameLength), 1440)
            let values = converted.floatChannelData![0]
            for i in 0..<fade {
                values[Int(converted.frameLength) - fade + i] *= Float(fade - i) / Float(fade)
            }
        }
        return converted
    }

    static func write(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        // AVAudioFile may be autoreleased; close it before consumers open the
        // file, otherwise its last partial packet may still be buffered.
        try autoreleasepool {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
    }
}

// All graph mutations and scheduling run on one high-priority queue. PCM is
// prepared once, outside the touch path; a tap only schedules an existing buffer.
final class InstrumentAudio {
    private let queue = DispatchQueue(label: "tinkon.audio", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var busyUntil: [Double] = []
    private var sources: [Int: AVAudioPCMBuffer] = [:]
    private var buffers: [Int: AVAudioPCMBuffer] = [:]
    private var pattern = Array(repeating: Array(repeating: false, count: 16), count: Kit.slotCount)
    private var bpm = 120
    private var looping = false
    private var epoch = 0
    private var nextStep = 0
    private var startTime = 0.0
    private var timer: DispatchSourceTimer?
    private var click: AVAudioPCMBuffer
    var onStep: ((Int, [Int]) -> Void)?
    var onRecorded: ((Int, Int) -> Void)?
    var onError: ((String) -> Void)?

    init() {
        click = AVAudioPCMBuffer(pcmFormat: SampleRenderer.format, frameCapacity: 1440)!
        click.frameLength = 1440
        for i in 0..<1440 {
            let t = Double(i) / SampleRenderer.sampleRate
            click.floatChannelData![0][i] = Float(sin(t * 2 * .pi * 1600) * exp(-t * 180) * 0.13)
        }
        for _ in 0..<32 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: SampleRenderer.format)
            players.append(player)
            busyUntil.append(0)
        }
        // A peak limiter keeps layered pad hits from clipping the output.
        let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        engine.attach(limiter)
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(engine.mainMixerNode, to: limiter, format: nil)
        engine.connect(limiter, to: engine.outputNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.75
    }

    private var now: Double { AVAudioTime.seconds(forHostTime: mach_absolute_time()) }

    private func activate() throws {
        guard !engine.isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setPreferredSampleRate(SampleRenderer.sampleRate)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        engine.prepare()
        try engine.start()
    }

    func install(_ pad: Pad?, at slot: Int, directory: URL) {
        queue.async {
            guard let pad else { self.buffers[slot] = nil; self.sources[slot] = nil; return }
            var source: AVAudioPCMBuffer
            if let name = pad.audioFile {
                do { source = try SampleRenderer.read(directory.appendingPathComponent(name), duration: pad.features.duration) }
                catch { source = SampleRenderer.synthesize(pad.features); self.report("Saved AI audio unavailable — using synth") }
            } else { source = SampleRenderer.synthesize(pad.features) }
            self.sources[slot] = source
            self.buffers[slot] = SampleRenderer.pitched(source, semitones: pad.pitch)
        }
    }

    func pitch(_ value: Int, slot: Int) {
        queue.async {
            guard let source = self.sources[slot] else { return }
            self.buffers[slot] = SampleRenderer.pitched(source, semitones: value)
        }
    }

    func update(pattern: [[Bool]], bpm: Int) {
        queue.async {
            self.pattern = pattern
            if self.bpm != bpm {
                self.bpm = bpm
                if self.looping { self.stopLocked(); self.startLocked() }
            }
        }
    }

    func tap(_ slot: Int) {
        queue.async {
            do {
                try self.activate()
                guard let buffer = self.buffers[slot] else { return }
                self.schedule(buffer, at: self.now)
                if self.looping {
                    let step = max(0, Int(((self.now - self.startTime) / self.stepDuration).rounded())) % 16
                    self.pattern[slot][step] = true
                    DispatchQueue.main.async { self.onRecorded?(slot, step) }
                }
            } catch { self.report("Audio unavailable: \(error.localizedDescription)") }
        }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, at time: Double) {
        let index = busyUntil.firstIndex(where: { $0 <= time }) ?? busyUntil.enumerated().min(by: { $0.element < $1.element })!.offset
        let player = players[index]
        if busyUntil[index] > time { player.stop() }
        let target = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: max(now, time)))
        player.scheduleBuffer(buffer, at: target)
        if !player.isPlaying { player.play() }
        busyUntil[index] = time + Double(buffer.frameLength) / buffer.format.sampleRate
    }

    private var stepDuration: Double { 60.0 / Double(bpm) / 4 }
    func start() { queue.async { self.startLocked() } }
    private func startLocked() {
        guard !looping else { return }
        do { try activate() } catch { report("Audio unavailable: \(error.localizedDescription)"); return }
        looping = true
        epoch += 1
        nextStep = 0
        startTime = now + 0.04
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timer.resume()
    }

    private func tick() {
        while looping && startTime + Double(nextStep) * stepDuration < now + 0.08 {
            let time = startTime + Double(nextStep) * stepDuration
            let step = nextStep % 16, generation = epoch
            let slots = pattern.indices.filter { pattern[$0][step] && buffers[$0] != nil }
            for slot in slots { schedule(buffers[slot]!, at: time) }
            if step % 4 == 0 { schedule(click, at: time) }
            queue.asyncAfter(deadline: .now() + max(0, time - now)) { [weak self] in
                guard let self, self.looping, self.epoch == generation else { return }
                DispatchQueue.main.async { self.onStep?(step, slots) }
            }
            nextStep += 1
        }
    }

    func stop() { queue.async { self.stopLocked() } }
    private func stopLocked() {
        looping = false
        epoch += 1
        timer?.cancel()
        timer = nil
        players.forEach { $0.stop() }
        busyUntil = Array(repeating: 0, count: players.count)
    }
    func suspend() {
        queue.async {
            self.stopLocked()
            self.engine.pause()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    private func report(_ message: String) { DispatchQueue.main.async { self.onError?(message) } }

    func export(slot: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        queue.async {
            do {
                guard let buffer = self.buffers[slot] else { throw CocoaError(.fileNoSuchFile) }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tink-on-P\(slot + 1)-\(UUID().uuidString).wav")
                try SampleRenderer.write(buffer, to: url)
                DispatchQueue.main.async { completion(.success(url)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
}
