import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

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
    let playlistHeaders: [String: String]?
    let deliveryType: String?
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

private struct DASHSegmentTemplate {
    let duration: Double
    let initialization: String
    let media: String
    let startNumber: Int
}

private struct DASHRepresentation {
    let id: String
    let contentType: String
    let codecs: String
    let bandwidth: Int
    let width: Int?
    let height: Int?
    let segmentTemplate: DASHSegmentTemplate
}

private struct DASHManifest {
    let duration: Double
    let video: [DASHRepresentation]
    let audio: [DASHRepresentation]
}

private enum DASHConversionError: Error {
    case invalidManifest
    case unsupportedManifest
}

private final class DASHManifestParser: NSObject, XMLParserDelegate {
    private var presentationDuration: Double?
    private var adaptationContentType = ""
    private var currentRepresentation: (id: String, contentType: String, codecs: String, bandwidth: Int, width: Int?, height: Int?)?
    private var currentTemplate: DASHSegmentTemplate?
    private var video: [DASHRepresentation] = []
    private var audio: [DASHRepresentation] = []

    static func parse(_ data: Data) throws -> DASHManifest {
        let delegate = DASHManifestParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(),
              let duration = delegate.presentationDuration,
              duration > 0,
              !delegate.video.isEmpty else {
            throw parser.parserError ?? DASHConversionError.invalidManifest
        }
        return DASHManifest(duration: duration, video: delegate.video, audio: delegate.audio)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "MPD":
            presentationDuration = Self.iso8601Duration(attributeDict["mediaPresentationDuration"])
        case "AdaptationSet":
            adaptationContentType = attributeDict["contentType"] ?? ""
        case "Representation":
            let mimeType = attributeDict["mimeType"] ?? ""
            let contentType = adaptationContentType.isEmpty
                ? (mimeType.hasPrefix("audio/") ? "audio" : "video")
                : adaptationContentType
            currentRepresentation = (
                id: attributeDict["id"] ?? UUID().uuidString,
                contentType: contentType,
                codecs: attributeDict["codecs"] ?? "",
                bandwidth: Int(attributeDict["bandwidth"] ?? "") ?? 1,
                width: Int(attributeDict["width"] ?? ""),
                height: Int(attributeDict["height"] ?? "")
            )
            currentTemplate = nil
        case "SegmentTemplate":
            guard currentRepresentation != nil,
                  let rawDuration = Double(attributeDict["duration"] ?? ""),
                  let initialization = attributeDict["initialization"],
                  let media = attributeDict["media"] else { return }
            let timescale = Double(attributeDict["timescale"] ?? "1") ?? 1
            guard timescale > 0 else { return }
            currentTemplate = DASHSegmentTemplate(
                duration: rawDuration / timescale,
                initialization: initialization,
                media: media,
                startNumber: Int(attributeDict["startNumber"] ?? "1") ?? 1
            )
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "Representation",
           let representation = currentRepresentation,
           let template = currentTemplate {
            let item = DASHRepresentation(
                id: representation.id,
                contentType: representation.contentType,
                codecs: representation.codecs,
                bandwidth: representation.bandwidth,
                width: representation.width,
                height: representation.height,
                segmentTemplate: template
            )
            if representation.contentType == "audio" {
                audio.append(item)
            } else {
                video.append(item)
            }
            currentRepresentation = nil
            currentTemplate = nil
        } else if elementName == "AdaptationSet" {
            adaptationContentType = ""
        }
    }

    private static func iso8601Duration(_ value: String?) -> Double? {
        guard let value else { return nil }
        let expression = try? NSRegularExpression(
            pattern: #"^PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?$"#
        )
        let range = NSRange(value.startIndex..., in: value)
        guard let match = expression?.firstMatch(in: value, range: range) else { return nil }
        func component(_ index: Int) -> Double {
            let range = match.range(at: index)
            guard range.location != NSNotFound,
                  let swiftRange = Range(range, in: value) else { return 0 }
            return Double(value[swiftRange]) ?? 0
        }
        return component(1) * 3600 + component(2) * 60 + component(3)
    }
}

public actor StreamResolver {
    public static let shared = StreamResolver()

    private let session: URLSession
    private let vidLinkPlaybackHeaders = [
        "Referer": "https://vidlink.pro/",
        "Origin": "https://vidlink.pro",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1"
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
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        for (field, value) in vidLinkPlaybackHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("webkit", forHTTPHeaderField: "X-Playback-Environment")
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")

        let response: VidLinkResponse = try await fetchJSON(VidLinkResponse.self, request: request)
        guard let stream = response.stream else { throw StreamResolverError.noPlayableSource }
        var headers = mergingHTTPHeaders(vidLinkPlaybackHeaders, with: stream.preferredHeaders ?? [:])
        headers = mergingHTTPHeaders(headers, with: stream.headers ?? [:])
        var sources: [StreamSource] = []

        if let playlist = stream.playlist, let playlistURL = URL(string: playlist) {
            let deliveryType = stream.deliveryType?.lowercased() ?? stream.type?.lowercased()
            if deliveryType == "dash" || playlistURL.pathExtension.lowercased() == "mpd" {
                let dashHeaders = mergingHTTPHeaders(headers, with: stream.playlistHeaders ?? [:])
                let hlsURL = try await convertDASHToHLS(manifestURL: playlistURL, headers: dashHeaders)
                sources.append(StreamSource(
                    url: hlsURL,
                    quality: .auto,
                    isHLS: true,
                    provider: .vidLink,
                    name: "Adaptive",
                    headers: dashHeaders
                ))
            } else {
                sources.append(StreamSource(
                    url: playlistURL,
                    quality: .auto,
                    isHLS: true,
                    provider: .vidLink,
                    name: "Adaptive",
                    headers: headers
                ))
            }
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
        let data = try await fetchData(request: request)
        if data == Data("null".utf8) { throw StreamResolverError.noPlayableSource }
        return try JSONDecoder().decode(type, from: data)
    }

    private func fetchData(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func convertDASHToHLS(manifestURL: URL, headers: [String: String]) async throws -> URL {
        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let manifest = try DASHManifestParser.parse(await fetchData(request: request))
        guard let baseURL = URL(string: ".", relativeTo: manifestURL)?.absoluteURL else {
            throw DASHConversionError.invalidManifest
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AurifyStreams", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let audio = manifest.audio.first
        var master = ["#EXTM3U", "#EXT-X-VERSION:7", "#EXT-X-INDEPENDENT-SEGMENTS"]
        if let audio {
            let audioName = "audio.m3u8"
            try mediaPlaylist(for: audio, manifest: manifest, baseURL: baseURL)
                .write(to: directory.appendingPathComponent(audioName), atomically: true, encoding: .utf8)
            master.append(#"#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Default",DEFAULT=YES,AUTOSELECT=YES,URI="audio.m3u8""#)
        }

        for representation in manifest.video.sorted(by: { $0.bandwidth > $1.bandwidth }) {
            let safeID = representation.id.replacingOccurrences(
                of: #"[^A-Za-z0-9_-]"#,
                with: "-",
                options: .regularExpression
            )
            let playlistName = "video-\(safeID).m3u8"
            try mediaPlaylist(for: representation, manifest: manifest, baseURL: baseURL)
                .write(to: directory.appendingPathComponent(playlistName), atomically: true, encoding: .utf8)

            var attributes = ["BANDWIDTH=\(representation.bandwidth)"]
            if let width = representation.width, let height = representation.height {
                attributes.append("RESOLUTION=\(width)x\(height)")
            }
            let codecs = [representation.codecs, audio?.codecs]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
            if !codecs.isEmpty { attributes.append(#"CODECS="\#(codecs)""#) }
            if audio != nil { attributes.append(#"AUDIO="audio""#) }
            master.append("#EXT-X-STREAM-INF:\(attributes.joined(separator: ","))")
            master.append(playlistName)
        }

        guard master.count > 3 else { throw DASHConversionError.unsupportedManifest }
        let masterURL = directory.appendingPathComponent("master.m3u8")
        try (master.joined(separator: "\n") + "\n")
            .write(to: masterURL, atomically: true, encoding: .utf8)
        return masterURL
    }

    private func mediaPlaylist(
        for representation: DASHRepresentation,
        manifest: DASHManifest,
        baseURL: URL
    ) throws -> String {
        let template = representation.segmentTemplate
        guard template.duration > 0 else { throw DASHConversionError.unsupportedManifest }
        let segmentCount = Int(ceil(manifest.duration / template.duration))
        guard segmentCount > 0 else { throw DASHConversionError.unsupportedManifest }

        let initialization = expandedDASHTemplate(
            template.initialization,
            representationID: representation.id,
            number: template.startNumber
        )
        guard let initializationURL = URL(string: initialization, relativeTo: baseURL)?.absoluteURL else {
            throw DASHConversionError.invalidManifest
        }

        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-TARGETDURATION:\(Int(ceil(template.duration)))",
            "#EXT-X-MEDIA-SEQUENCE:\(template.startNumber)",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            #"#EXT-X-MAP:URI="\#(initializationURL.absoluteString)""#
        ]
        for offset in 0..<segmentCount {
            let elapsed = Double(offset) * template.duration
            let duration = min(template.duration, manifest.duration - elapsed)
            let path = expandedDASHTemplate(
                template.media,
                representationID: representation.id,
                number: template.startNumber + offset
            )
            guard let segmentURL = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
                throw DASHConversionError.invalidManifest
            }
            lines.append(String(format: "#EXTINF:%.3f,", locale: Locale(identifier: "en_US_POSIX"), duration))
            lines.append(segmentURL.absoluteString)
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }

    private func expandedDASHTemplate(_ template: String, representationID: String, number: Int) -> String {
        var result = template.replacingOccurrences(of: "$RepresentationID$", with: representationID)
        if let expression = try? NSRegularExpression(pattern: #"\$Number%0(\d+)d\$"#),
           let match = expression.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let matchRange = Range(match.range(at: 0), in: result),
           let widthRange = Range(match.range(at: 1), in: result),
           let width = Int(result[widthRange]) {
            let formatted = String(format: "%0\(width)d", number)
            result.replaceSubrange(matchRange, with: formatted)
        }
        return result.replacingOccurrences(of: "$Number$", with: String(number))
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
