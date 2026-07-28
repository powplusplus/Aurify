import Foundation

public struct ResolvedMediaStream: Codable, Hashable {
    public let sources: [StreamSource]
    public let subtitles: [SubtitleTrack]
    public let activeProvider: ServerProvider

    public init(sources: [StreamSource], subtitles: [SubtitleTrack], activeProvider: ServerProvider) {
        self.sources = sources
        self.subtitles = subtitles
        self.activeProvider = activeProvider
    }
}

public enum StreamResolverError: LocalizedError {
    case invalidEpisode
    case providerUnavailable(String)
    case noPlayableSource
    case customResolverNotConfigured
    case invalidCustomResolver

    public var errorDescription: String? {
        switch self {
        case .invalidEpisode:
            return "Select a season and episode before playing."
        case let .providerUnavailable(message):
            return message
        case .noPlayableSource:
            return "Z-Stream's providers did not return a playable source for this title."
        case .customResolverNotConfigured:
            return "Add a custom resolver URL in Settings first."
        case .invalidCustomResolver:
            return "The custom resolver returned an unsupported response."
        }
    }
}

private struct EncryptionResponse: Decodable { let result: String }

private struct VidLinkResponse: Decodable {
    let sourceId: String?
    let stream: VidLinkStream?
}

private struct VidLinkStream: Decodable {
    let id: String?
    let type: String?
    let qualities: [String: VidLinkQuality]?
    let playlist: String?
    let captions: [VidLinkCaption]?
    let headers: [String: String]?
    let preferredHeaders: [String: String]?
}

private struct VidLinkQuality: Decodable {
    let type: String?
    let url: String
    let headers: [String: String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            type = nil
            url = value
            headers = nil
            return
        }
        let object = try decoder.container(keyedBy: CodingKeys.self)
        type = try object.decodeIfPresent(String.self, forKey: .type)
        url = try object.decode(String.self, forKey: .url)
        headers = try object.decodeIfPresent([String: String].self, forKey: .headers)
    }

    private enum CodingKeys: String, CodingKey { case type, url, headers }
}

private struct VidLinkCaption: Decodable {
    let id: String?
    let url: String
    let language: String?
    let display: String?
    let type: String?
    let isHearingImpaired: Bool?
}

private struct VDRKCaption: Decodable {
    let file: String
    let label: String
}

private struct CustomResolverPayload: Decodable {
    let sources: [CustomResolverSource]
    let subtitles: [CustomResolverSubtitle]?
}

private struct CustomResolverSource: Decodable {
    let url: String
    let quality: String?
    let type: String?
    let name: String?
    let headers: [String: String]?
}

private struct CustomResolverSubtitle: Decodable {
    let url: String
    let language: String?
    let label: String?
    let format: String?
}

public actor StreamResolver {
    public static let shared = StreamResolver()

    private let session: URLSession
    private let vidLinkPlaybackHeaders = [
        "Referer": "https://vidlink.pro/",
        "Origin": "https://vidlink.pro",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36"
    ]

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 22
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    public func resolveStream(
        tmdbId: Int,
        mediaType: MediaType,
        season: Int? = nil,
        episode: Int? = nil,
        preferredProvider: ServerProvider = .zstreamAuto
    ) async throws -> ResolvedMediaStream {
        if mediaType == .tv, (season == nil || episode == nil) {
            throw StreamResolverError.invalidEpisode
        }

        let providers: [ServerProvider]
        switch preferredProvider {
        case .zstreamAuto:
            providers = UserSettings.shared.customResolverURL.isEmpty ? [.vidLink] : [.vidLink, .custom]
        case .vidLink:
            providers = [.vidLink]
        case .custom:
            providers = [.custom, .vidLink]
        }

        var failures: [String] = []
        for provider in providers {
            do {
                var result: ResolvedMediaStream
                switch provider {
                case .zstreamAuto:
                    continue
                case .vidLink:
                    result = try await resolveVidLink(tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode)
                case .custom:
                    result = try await resolveCustom(tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode)
                }

                let external = await fetchExternalSubtitles(tmdbId: tmdbId, mediaType: mediaType, season: season, episode: episode)
                let subtitles = deduplicateSubtitles(result.subtitles + external)
                return ResolvedMediaStream(sources: result.sources, subtitles: subtitles, activeProvider: result.activeProvider)
            } catch {
                failures.append("\(provider.rawValue): \(error.localizedDescription)")
            }
        }

        if failures.isEmpty { throw StreamResolverError.noPlayableSource }
        throw StreamResolverError.providerUnavailable(failures.joined(separator: "\n"))
    }

    private func resolveVidLink(tmdbId: Int, mediaType: MediaType, season: Int?, episode: Int?) async throws -> ResolvedMediaStream {
        var encryptComponents = URLComponents(string: "https://enc-dec.app/api/enc-vidlink")!
        encryptComponents.queryItems = [URLQueryItem(name: "text", value: String(tmdbId))]
        let encryption: EncryptionResponse = try await fetchJSON(EncryptionResponse.self, url: encryptComponents.url!)

        let encodedId = encryption.result.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? encryption.result
        let path: String
        if mediaType == .movie {
            path = "movie/\(encodedId)"
        } else {
            path = "tv/\(encodedId)/\(season!)/\(episode!)"
        }
        guard let url = URL(string: "https://vidlink.pro/api/b/\(path)") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        for (field, value) in vidLinkPlaybackHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let response: VidLinkResponse = try await fetchJSON(VidLinkResponse.self, request: request)
        guard let stream = response.stream else { throw StreamResolverError.noPlayableSource }
        var headers = mergingHTTPHeaders(vidLinkPlaybackHeaders, with: stream.preferredHeaders ?? [:])
        headers = mergingHTTPHeaders(headers, with: stream.headers ?? [:])
        var sources: [StreamSource] = []

        if let playlist = stream.playlist, let playlistURL = URL(string: playlist) {
            sources.append(StreamSource(
                url: playlistURL,
                quality: .auto,
                isHLS: true,
                provider: .vidLink,
                name: "Adaptive",
                headers: headers
            ))
        }

        for (label, quality) in stream.qualities ?? [:] {
            guard let sourceURL = URL(string: quality.url) else { continue }
            let mappedQuality = StreamQuality.from(providerValue: label)
            let isHLS = quality.type?.lowercased() == "hls" || sourceURL.pathExtension.lowercased() == "m3u8"
            let sourceHeaders = mergingHTTPHeaders(headers, with: quality.headers ?? [:])
            sources.append(StreamSource(
                url: sourceURL,
                quality: mappedQuality,
                isHLS: isHLS,
                provider: .vidLink,
                name: label.uppercased(),
                headers: sourceHeaders
            ))
        }

        guard !sources.isEmpty else { throw StreamResolverError.noPlayableSource }
        sources = sortSources(sources)

        let captions = (stream.captions ?? []).compactMap { caption -> SubtitleTrack? in
            guard let url = URL(string: caption.url) else { return nil }
            let language = normalizedLanguageCode(caption.language ?? caption.display ?? "und")
            return SubtitleTrack(
                id: caption.id ?? caption.url,
                language: language,
                label: caption.display ?? displayLanguage(language),
                url: url,
                format: caption.type?.lowercased() == "srt" ? .subRip : .webVTT,
                source: "VidLink",
                isHearingImpaired: caption.isHearingImpaired ?? false
            )
        }
        return ResolvedMediaStream(sources: sources, subtitles: captions, activeProvider: .vidLink)
    }

    private func resolveCustom(tmdbId: Int, mediaType: MediaType, season: Int?, episode: Int?) async throws -> ResolvedMediaStream {
        let rawBase = UserSettings.shared.customResolverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawBase.isEmpty else { throw StreamResolverError.customResolverNotConfigured }
        guard var components = URLComponents(string: rawBase) else { throw StreamResolverError.invalidCustomResolver }
        var items = components.queryItems ?? []
        items.append(contentsOf: [
            URLQueryItem(name: "tmdbId", value: String(tmdbId)),
            URLQueryItem(name: "type", value: mediaType.rawValue)
        ])
        if let season { items.append(URLQueryItem(name: "season", value: String(season))) }
        if let episode { items.append(URLQueryItem(name: "episode", value: String(episode))) }
        components.queryItems = items
        guard let url = components.url else { throw StreamResolverError.invalidCustomResolver }

        let payload: CustomResolverPayload = try await fetchJSON(CustomResolverPayload.self, url: url)
        let sources = payload.sources.compactMap { item -> StreamSource? in
            guard let url = URL(string: item.url) else { return nil }
            return StreamSource(
                url: url,
                quality: StreamQuality.from(providerValue: item.quality ?? "auto"),
                isHLS: item.type?.lowercased() == "hls" || url.pathExtension.lowercased() == "m3u8",
                provider: .custom,
                name: item.name,
                headers: item.headers ?? [:]
            )
        }
        guard !sources.isEmpty else { throw StreamResolverError.invalidCustomResolver }
        let subtitles = (payload.subtitles ?? []).compactMap { item -> SubtitleTrack? in
            guard let url = URL(string: item.url) else { return nil }
            let language = normalizedLanguageCode(item.language ?? "und")
            return SubtitleTrack(
                language: language,
                label: item.label ?? displayLanguage(language),
                url: url,
                format: item.format?.lowercased() == "srt" ? .subRip : .webVTT,
                source: "Custom"
            )
        }
        return ResolvedMediaStream(sources: sortSources(sources), subtitles: subtitles, activeProvider: .custom)
    }

    private func fetchExternalSubtitles(tmdbId: Int, mediaType: MediaType, season: Int?, episode: Int?) async -> [SubtitleTrack] {
        let path = mediaType == .movie
            ? "movie/\(tmdbId)"
            : "tv/\(tmdbId)/\(season ?? 1)/\(episode ?? 1)"
        guard let url = URL(string: "https://sub.vdrk.site/v1/\(path)"),
              let response = try? await fetchJSON([VDRKCaption].self, url: url) else { return [] }
        return response.compactMap { item in
            guard let url = URL(string: item.file) else { return nil }
            let language = normalizedLanguageCode(item.label)
            return SubtitleTrack(
                id: item.file,
                language: language,
                label: item.label,
                url: url,
                format: url.pathExtension.lowercased() == "srt" ? .subRip : .webVTT,
                source: "VDRK",
                isHearingImpaired: item.label.localizedCaseInsensitiveContains(" hi")
            )
        }
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        try await fetchJSON(type, request: URLRequest(url: url))
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        if data == Data("null".utf8) { throw StreamResolverError.noPlayableSource }
        return try JSONDecoder().decode(type, from: data)
    }

    private func sortSources(_ sources: [StreamSource]) -> [StreamSource] {
        let preferred = UserSettings.shared.defaultQuality
        return sources.sorted { lhs, rhs in
            let lhsPreferred = lhs.quality == preferred
            let rhsPreferred = rhs.quality == preferred
            if lhsPreferred != rhsPreferred { return lhsPreferred }
            let lhsAdaptive = lhs.quality == .auto
            let rhsAdaptive = rhs.quality == .auto
            if lhsAdaptive != rhsAdaptive { return lhsAdaptive }
            if lhs.quality == rhs.quality { return lhs.name < rhs.name }
            return lhs.quality > rhs.quality
        }
    }

    private func mergingHTTPHeaders(
        _ base: [String: String],
        with overrides: [String: String]
    ) -> [String: String] {
        var result = base
        for (field, value) in overrides {
            if let existing = result.keys.first(where: {
                $0.caseInsensitiveCompare(field) == .orderedSame
            }) {
                result.removeValue(forKey: existing)
            }
            result[field] = value
        }
        return result
    }

    private func deduplicateSubtitles(_ subtitles: [SubtitleTrack]) -> [SubtitleTrack] {
        var seen = Set<String>()
        return subtitles.filter { seen.insert($0.url.absoluteString).inserted }
            .sorted { lhs, rhs in
                let preferred = UserSettings.shared.preferredSubtitleLanguage.lowercased()
                let lhsPreferred = lhs.language.lowercased() == preferred
                let rhsPreferred = rhs.language.lowercased() == preferred
                if lhsPreferred != rhsPreferred { return lhsPreferred }
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
    }

    private func normalizedLanguageCode(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: #"\s*HI\d*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleaned.lowercased()
        let aliases: [String: String] = [
            "english": "en", "spanish": "es", "french": "fr", "german": "de",
            "italian": "it", "portuguese": "pt", "japanese": "ja", "korean": "ko",
            "chinese": "zh", "arabic": "ar", "hindi": "hi", "dutch": "nl",
            "polish": "pl", "turkish": "tr", "russian": "ru"
        ]
        if let alias = aliases.first(where: { lower.contains($0.key) })?.value { return alias }
        let prefix = lower.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " }).first.map(String.init) ?? lower
        return prefix.count >= 2 && prefix.count <= 3 ? prefix : "und"
    }

    private func displayLanguage(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
}
