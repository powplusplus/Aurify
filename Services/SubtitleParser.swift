import Foundation

public actor SubtitleParser {
    public static let shared = SubtitleParser()
    
    private init() {}

    public func fetchAndParse(url: URL) async throws -> [SubtitleCue] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return parseSubtitleContent(content)
    }

    public func parseSubtitleContent(_ content: String) -> [SubtitleCue] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        
        var cues: [SubtitleCue] = []

        for block in blocks {
            let lines = block.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }
            
            // Skip WEBVTT header or numeric index line if present
            var timeLineIndex = 0
            if lines[0].lowercased().contains("webvtt") || lines[0].lowercased().contains("kind:") {
                continue
            }
            if Int(lines[0]) != nil && lines.count > 1 {
                timeLineIndex = 1
            }

            guard timeLineIndex < lines.count else { continue }
            let timeLine = lines[timeLineIndex]

            if timeLine.contains("-->") {
                let times = timeLine.components(separatedBy: "-->")
                guard times.count == 2 else { continue }
                
                let startTimeStr = times[0].trimmingCharacters(in: .whitespaces)
                let endTimeStr = times[1].components(separatedBy: " ")[0].trimmingCharacters(in: .whitespaces)
                
                if let startTime = parseTimestamp(startTimeStr),
                   let endTime = parseTimestamp(endTimeStr) {
                    
                    let textLines = Array(lines[(timeLineIndex + 1)...])
                    let text = textLines.joined(separator: "\n")
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip HTML tags
                    
                    if !text.isEmpty {
                        cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
                    }
                }
            }
        }
        
        return cues
    }

    private func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let components = timestamp.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard components.count >= 2 else { return nil }

        var hours: TimeInterval = 0.0
        var minutes: TimeInterval = 0.0
        var seconds: TimeInterval = 0.0

        if components.count == 3 {
            hours = TimeInterval(components[0]) ?? 0.0
            minutes = TimeInterval(components[1]) ?? 0.0
            seconds = TimeInterval(components[2]) ?? 0.0
        } else if components.count == 2 {
            minutes = TimeInterval(components[0]) ?? 0.0
            seconds = TimeInterval(components[1]) ?? 0.0
        }

        return (hours * 3600.0) + (minutes * 60.0) + seconds
    }
}
