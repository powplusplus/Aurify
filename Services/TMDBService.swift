import Foundation

public enum CatalogError: LocalizedError {
    case missingCredential
    case invalidResponse
    case server(status: Int, message: String?)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "Add a TMDB Read Access Token in Settings to load the catalog."
        case .invalidResponse:
            return "The catalog returned an invalid response."
        case let .server(status, message):
            return message?.isEmpty == false ? message : "The catalog request failed (HTTP \(status))."
        case let .decoding(error):
            return "The catalog response could not be read: \(error.localizedDescription)"
        }
    }
}

private struct TMDBAPIError: Decodable {
    let statusMessage: String?
    enum CodingKeys: String, CodingKey { case statusMessage = "status_message" }
}

public actor TMDBService {
    public static let shared = TMDBService()

    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    private let zStreamConfigURL = URL(string: "https://zstream.mov/config.js")!
    private let session: URLSession
    private var cachedSiteCredential: String?
    private var didCheckSiteConfiguration = false

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 35
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    public func refreshConfiguration() {
        cachedSiteCredential = nil
        didCheckSiteConfiguration = false
    }

    private func credential() async throws -> String {
        let userValue = UserSettings.shared.customTMDBKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userValue.isEmpty { return userValue }

        if let bundled = Bundle.main.object(forInfoDictionaryKey: "TMDBReadToken") as? String {
            let value = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, !value.hasPrefix("$(") { return value }
        }

        if !didCheckSiteConfiguration {
            didCheckSiteConfiguration = true
            cachedSiteCredential = try? await fetchCredentialFromZStreamConfiguration()
        }
        guard let cachedSiteCredential, !cachedSiteCredential.isEmpty else {
            throw CatalogError.missingCredential
        }
        return cachedSiteCredential
    }

    private func fetchCredentialFromZStreamConfiguration() async throws -> String? {
        let (data, response) = try await session.data(from: zStreamConfigURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let source = String(data: data, encoding: .utf8) else { return nil }

        let pattern = #"VITE_TMDB_READ_API_KEY\s*:\s*[\"']([^\"']+)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source) else { return nil }
        let value = String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func buildRequest(endpoint: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        let token = try await credential()
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        var items = queryItems
        items.append(URLQueryItem(name: "language", value: UserSettings.shared.metadataLanguage))
        if token.split(separator: ".").count != 3 {
            items.append(URLQueryItem(name: "api_key", value: token))
        }
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if token.split(separator: ".").count == 3 {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func request<T: Decodable>(_ type: T.Type, endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let request = try await buildRequest(endpoint: endpoint, queryItems: queryItems)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CatalogError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            let message = try? JSONDecoder().decode(TMDBAPIError.self, from: data).statusMessage
            throw CatalogError.server(status: http.statusCode, message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CatalogError.decoding(error)
        }
    }

    public func fetchTrending(mediaType: MediaType = .movie, timeWindow: String = "day") async throws -> [MediaItem] {
        let response: TMDBResponse = try await request(TMDBResponse.self, endpoint: "/trending/\(mediaType.rawValue)/\(timeWindow)")
        return response.results.filter { $0.posterPath != nil || $0.backdropPath != nil }
    }

    public func fetchPopular(mediaType: MediaType = .movie, page: Int = 1) async throws -> [MediaItem] {
        let response: TMDBResponse = try await request(
            TMDBResponse.self,
            endpoint: "/\(mediaType.rawValue)/popular",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
        return response.results
    }

    public func fetchTopRated(mediaType: MediaType = .movie, page: Int = 1) async throws -> [MediaItem] {
        let response: TMDBResponse = try await request(
            TMDBResponse.self,
            endpoint: "/\(mediaType.rawValue)/top_rated",
            queryItems: [URLQueryItem(name: "page", value: String(page))]
        )
        return response.results
    }

    public func searchMedia(query: String, page: Int = 1) async throws -> [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: TMDBResponse = try await request(
            TMDBResponse.self,
            endpoint: "/search/multi",
            queryItems: [
                URLQueryItem(name: "query", value: trimmed),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: UserSettings.shared.includeAdultContent ? "true" : "false")
            ]
        )
        return response.results.filter { ($0.mediaType == .movie || $0.mediaType == .tv) && ($0.posterPath != nil || $0.backdropPath != nil) }
    }

    public func fetchDetail(id: Int, mediaType: MediaType) async throws -> MediaItem {
        try await request(MediaItem.self, endpoint: "/\(mediaType.rawValue)/\(id)")
    }

    public func fetchSeasonDetail(tvId: Int, seasonNumber: Int) async throws -> SeasonDetail {
        try await request(SeasonDetail.self, endpoint: "/tv/\(tvId)/season/\(seasonNumber)")
    }

    public func fetchGenres(mediaType: MediaType = .movie) async throws -> [Genre] {
        struct GenreResponse: Decodable { let genres: [Genre] }
        let response: GenreResponse = try await request(GenreResponse.self, endpoint: "/genre/\(mediaType.rawValue)/list")
        return response.genres
    }
}
