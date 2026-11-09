import Foundation

struct SoundService {
    let endpoint: URL
    var session: URLSession = .shared

    func generate(_ features: SoundFeatures, directory: URL) async throws -> String {
        guard endpoint.scheme == "https" else { throw URLError(.badURL) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 55
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Prompt(prompt: features.prompt, durationSec: features.duration))
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              !data.isEmpty, data.count <= 2_000_000 else { throw URLError(.badServerResponse) }
        let fileExtension: String
        switch response.mimeType {
        case "audio/mpeg": fileExtension = "mp3"
        case "audio/wav", "audio/x-wav": fileExtension = "wav"
        default: throw URLError(.badServerResponse)
        }
        try Task.checkCancellation()
        let temporary = directory.appendingPathComponent("download-\(UUID().uuidString).\(fileExtension)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .atomic)
        let buffer = try SampleRenderer.read(temporary, duration: features.duration)
        try Task.checkCancellation()
        let name = "sound-\(UUID().uuidString).caf"
        try SampleRenderer.write(buffer, to: directory.appendingPathComponent(name))
        return name
    }

    private struct Prompt: Encodable {
        let prompt: String
        let durationSec: Double
    }
}
