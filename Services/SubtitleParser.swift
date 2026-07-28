import Foundation

public actor SubtitleParser {
    public static let shared = SubtitleParser()
    private var cache: [URL: [SubtitleCue]] = [:]
    private init() {}

    public func fetchAndParse(url: URL, headers: [String: String] = [:]) async throws -> [SubtitleCue] {
        if let cached = cache[url] { return cached }
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        let content = decode(data)
        let cues = parseSubtitleContent(content)
        cache[url] = cues
        return cues
    }

    public func parseSubtitleContent(_ content: String) -> [SubtitleCue] {
        let normalized = content
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [SubtitleCue] = []

        for block in blocks {
            let rawLines = block.components(separatedBy: "\n")
            guard let timeIndex = rawLines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let timeline = rawLines[timeIndex].components(separatedBy: "-->")
            guard timeline.count == 2,
                  let start = parseTimestamp(timeline[0]),
                  let end = parseTimestamp(timeline[1].split(separator: " ").first.map(String.init) ?? timeline[1]) else { continue }

            let text = rawLines.dropFirst(timeIndex + 1)
                .joined(separator: "\n")
                .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\{\\[^}]+\}"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty, end > start {
                cues.append(SubtitleCue(startTime: start, endTime: end, text: text))
            }
        }
        return cues.sorted { $0.startTime < $1.startTime }
    }

    private func parseTimestamp(_ value: String) -> TimeInterval? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let pieces = cleaned.split(separator: ":").compactMap { Double($0) }
        if pieces.count == 3 { return pieces[0] * 3600 + pieces[1] * 60 + pieces[2] }
        if pieces.count == 2 { return pieces[0] * 60 + pieces[1] }
        return nil
    }

    private func decode(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
        return String(decoding: data, as: UTF8.self)
    }
}
