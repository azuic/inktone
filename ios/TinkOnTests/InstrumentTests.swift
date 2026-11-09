import XCTest
import AVFoundation
@testable import TinkOn

final class InstrumentTests: XCTestCase {
    private func stroke(_ ink: Ink = .blue, height: Double = 0.2) -> Stroke {
        Stroke(ink: ink, points: [SketchPoint(x: 0.1, y: height, time: 0), SketchPoint(x: 0.9, y: height, time: 0.5)])
    }
    func testSketchMappingBoundsAndInkDominance() throws {
        XCTAssertNil(SoundFeatures.analyze([]))
        let high = try XCTUnwrap(SoundFeatures.analyze([stroke(height: 0.1)]))
        let low = try XCTUnwrap(SoundFeatures.analyze([stroke(height: 0.9)]))
        XCTAssertGreaterThan(high.frequency, low.frequency)
        XCTAssertEqual(high.ink, .blue)
        XCTAssertTrue((0.25...1.6).contains(high.duration))
        XCTAssertTrue(high.prompt.contains("resonant tone"))
        var short = stroke(.pink)
        short.points[1].x = 0.2
        XCTAssertEqual(SoundFeatures.analyze([short, stroke(.orange)])?.ink, .orange)
        XCTAssertNotNil(SoundFeatures.analyze([Stroke(ink: .yellow, points: [SketchPoint(x: 0.5, y: 0.5, time: 0)])]))
    }
    func testAllSynthVoicesAreFiniteAudibleAndFadeOut() throws {
        for ink in Ink.allCases {
            let features = try XCTUnwrap(SoundFeatures.analyze([stroke(ink)]))
            let buffer = SampleRenderer.synthesize(features)
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
            XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 }, "\(ink)")
            XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.05, "\(ink)")
            XCTAssertLessThan(abs(samples.last ?? 1), 0.001, "\(ink)")
            let octave = SampleRenderer.pitched(buffer, semitones: 12)
            XCTAssertEqual(Double(octave.frameLength), Double(buffer.frameLength) / 2, accuracy: 1)
        }
    }
    func testSavedKitAndAudioRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = try KitStorage(directory: directory)
        let features = try XCTUnwrap(SoundFeatures.analyze([stroke(.orange)]))
        var kit = Kit()
        kit.pads[11] = Pad(features: features, strokes: [stroke(.orange)], pitch: -3, audioFile: "sound.caf")
        kit.pattern[11][7] = true
        kit.bpm = 135
        kit.selected = 11
        kit.strokes = [stroke()]
        try storage.save(kit)
        let restored = try storage.load()
        XCTAssertEqual(restored.pads[11]?.pitch, -3)
        XCTAssertTrue(restored.pattern[11][7])
        XCTAssertEqual(restored.bpm, 135)
        XCTAssertEqual(restored.strokes, kit.strokes)
        let audio = SampleRenderer.synthesize(features)
        let url = directory.appendingPathComponent("sound.caf")
        try SampleRenderer.write(audio, to: url)
        let decoded = try SampleRenderer.read(url, duration: features.duration)
        XCTAssertEqual(decoded.frameLength, audio.frameLength)
        var invalid = kit
        invalid.pattern = []
        try storage.save(invalid)
        XCTAssertThrowsError(try storage.load())
    }
    func testEightPadKitExpandsWithoutLosingSoundsOrRecordedSteps() throws {
        var original = Kit()
        let strokes = [stroke(.pink)]
        original.pads[7] = Pad(features: try XCTUnwrap(SoundFeatures.analyze(strokes)), strokes: strokes, pitch: 5)
        original.pattern[7][15] = true
        original.selected = 7
        original.bpm = 145
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["version"] = 1
        json["pads"] = Array((json["pads"] as! [Any]).prefix(8))
        json["pattern"] = Array((json["pattern"] as! [Any]).prefix(8))
        let restored = try JSONDecoder().decode(Kit.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.version, 2)
        XCTAssertEqual(restored.pads.count, 12)
        XCTAssertEqual(restored.pads[7]?.id, original.pads[7]?.id)
        XCTAssertEqual(restored.pads[7]?.pitch, 5)
        XCTAssertTrue(restored.pattern[7][15])
        XCTAssertEqual(restored.selected, 7)
        XCTAssertEqual(restored.bpm, 145)
        for slot in 8..<12 {
            XCTAssertNil(restored.pads[slot])
            XCTAssertFalse(restored.pattern[slot].contains(true))
        }
        // A damaged legacy beat must still be rejected, rather than repaired silently.
        json["pattern"] = Array(repeating: [false], count: 8)
        let invalid = try JSONDecoder().decode(Kit.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(invalid.isValid)
    }

    func testPixelPreviewFollowsSketchRatherThanFillingBoard() {
        let cells = PadArtwork.pixelate([stroke()])
        XCTAssertGreaterThan(cells.filter { $0.opacity > 0 }.count, 5)
        XCTAssertLessThan(cells.filter { $0.opacity > 0 }.count, 30)
        XCTAssertTrue(PadArtwork.pixelate([]).allSatisfy { $0.opacity == 0 })
    }


    func testPixelPreviewHasCoverageTransparencyAndLengthRankedTones() {
        let diagonal = Stroke(ink: .blue, points: [SketchPoint(x: 0.1, y: 0.1, time: 0), SketchPoint(x: 0.9, y: 0.9, time: 1)])
        let dots = PadArtwork.pixelate([diagonal]).filter { $0.opacity > 0 }
        XCTAssertGreaterThan(Set(dots.map { $0.opacity }).count, 1, "Edge coverage should produce multiple opacities")
        XCTAssertTrue(dots.allSatisfy { $0.gray == 20.0 / 255 && $0.opacity >= 0.6 && $0.opacity <= 1 })
        var shortBlue = stroke(.blue, height: 0.2)
        shortBlue.points[1].x = 0.3
        let mixed = PadArtwork.pixelate([shortBlue, stroke(.pink, height: 0.7)])
        let blueDots = Array(mixed[0..<65]).filter { $0.opacity > 0 }
        let pinkDots = Array(mixed[91..<169]).filter { $0.opacity > 0 }
        XCTAssertFalse(blueDots.isEmpty)
        XCTAssertFalse(pinkDots.isEmpty)
        XCTAssertTrue(blueDots.allSatisfy { $0.gray == 155.0 / 255 }, "Less-used ink should be light gray")
        XCTAssertTrue(pinkDots.allSatisfy { $0.gray == 20.0 / 255 }, "Longest ink should be near-black regardless of ink order")
        let dot = Stroke(ink: .orange, points: [SketchPoint(x: 0.5, y: 0.5, time: 0)])
        XCTAssertTrue(PadArtwork.pixelate([dot]).contains { $0.opacity > 0 }, "A single touch remains visible")
    }

    func testLocalOnlyBuild7KitStillLoadsWithAIInitiallyOff() throws {
        var kit = Kit()
        XCTAssertTrue(kit.aiEnabled, "New installs should select AI")
        XCTAssertFalse(kit.aiConsentGranted, "Default selection must not grant permission")
        kit.strokes = [stroke(.pink)]
        kit.pads[1] = Pad(features: try XCTUnwrap(SoundFeatures.analyze(kit.strokes)), strokes: kit.strokes)
        kit.pattern[1][4] = true
        kit.bpm = 155
        var oldJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(kit)) as? [String: Any])
        oldJSON.removeValue(forKey: "aiEnabled")
        oldJSON.removeValue(forKey: "aiConsentGranted")
        let restored = try JSONDecoder().decode(Kit.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        XCTAssertFalse(restored.aiEnabled)
        XCTAssertFalse(restored.aiConsentGranted)
        XCTAssertEqual(restored.strokes, kit.strokes)
        XCTAssertEqual(restored.pads[1]?.id, kit.pads[1]?.id)
        XCTAssertTrue(restored.pattern[1][4])
        XCTAssertEqual(restored.bpm, 155)
        kit.aiEnabled = true
        XCTAssertTrue(try JSONDecoder().decode(Kit.self, from: JSONEncoder().encode(kit)).aiEnabled)
        kit.aiEnabled = false
        XCTAssertFalse(try JSONDecoder().decode(Kit.self, from: JSONEncoder().encode(kit)).aiEnabled)
        kit.aiEnabled = true
        kit.aiConsentGranted = true
        XCTAssertTrue(try JSONDecoder().decode(Kit.self, from: JSONEncoder().encode(kit)).aiConsentGranted)
    }

    func testAIRequestStoresPlayableAudioAndRejectsQuotaOrInvalidResponses() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let features = try XCTUnwrap(SoundFeatures.analyze([stroke()]))
        let fixture = directory.appendingPathComponent("fixture.wav")
        try SampleRenderer.write(SampleRenderer.synthesize(features), to: fixture)
        let audioData = try Data(contentsOf: fixture)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SoundStub.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); SoundStub.handler = nil }
        let service = SoundService(endpoint: URL(string: "https://example.invalid/api/generate-sound")!, session: session)
        SoundStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var body = Data()
            var bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                body.append(contentsOf: bytes.prefix(count))
            }
            let prompt = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(Set(prompt.keys), ["prompt", "durationSec"])
            XCTAssertEqual(prompt["prompt"] as? String, features.prompt)
            return (200, "audio/wav", audioData)
        }
        let name = try await service.generate(features, directory: directory)
        let decoded = try SampleRenderer.read(directory.appendingPathComponent(name), duration: features.duration)
        XCTAssertGreaterThan(decoded.frameLength, 0)
        XCTAssertEqual(decoded.format.sampleRate, 48000)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix("download-") })
        for (status, type, data) in [(429, "application/json", Data("quota".utf8)), (200, "audio/mpeg", Data("invalid audio".utf8))] {
            SoundStub.handler = { _ in (status, type, data) }
            do {
                _ = try await service.generate(features, directory: directory)
                XCTFail("A failed AI response must not create a pad's audio file")
            } catch {}
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("sound-") }.count, 1)
        SoundStub.handler = { _ in (200, "audio/wav", audioData) }
        let cancelled = Task { try await service.generate(features, directory: directory) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("Cancelled generation must not install a new audio file")
        } catch {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("sound-") }.count, 1)
    }

    func testStereoAudioResamplesAndTrimsToSketchDuration() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        for channel in 0..<2 {
            for frame in 0..<44100 {
                buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) / 44100 * 2 * .pi * 440) * 0.3)
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try autoreleasepool {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let converted = try SampleRenderer.read(url, duration: 0.6)
        XCTAssertEqual(converted.format.sampleRate, 48000)
        XCTAssertEqual(converted.format.channelCount, 1)
        XCTAssertEqual(converted.frameLength, 28800)
        XCTAssertLessThan(abs(converted.floatChannelData![0][28799]), 0.001)
    }
}

private final class SoundStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            // A cancelled request may reach the stub after the test has cleared it.
            guard let handler = Self.handler else { throw URLError(.cancelled) }
            let (status, type, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": type])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
