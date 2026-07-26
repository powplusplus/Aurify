import Foundation

public actor TMDBService {
    public static let shared = TMDBService()
    
    // Built-in public demo key fallback + dynamic key support
    private let fallbackApiKey = "15d2900ab2629b16733e25b377726487"
    private let baseURL = "https://api.themoviedb.org/3"

    private var apiKey: String {
        let userKey = UserSettings.shared.customTMDBKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return userKey.isEmpty ? fallbackApiKey : userKey
    }

    private init() {}

    private func buildURL(endpoint: String, queryItems: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)\(endpoint)") else { return nil }
        var items = [URLQueryItem(name: "api_key", value: apiKey)]
        items.append(contentsOf: queryItems)
        components.queryItems = items
        return components.url
    }

    public func fetchTrending(mediaType: MediaType = .movie, timeWindow: String = "day") async throws -> [MediaItem] {
        guard let url = buildURL(endpoint: "/trending/\(mediaType.rawValue)/\(timeWindow)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return decoded.results
    }

    public func fetchPopular(mediaType: MediaType = .movie, page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(endpoint: "/\(mediaType.rawValue)/popular", queryItems: [URLQueryItem(name: "page", value: "\(page)")]) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return decoded.results
    }

    public func fetchTopRated(mediaType: MediaType = .movie, page: Int = 1) async throws -> [MediaItem] {
        guard let url = buildURL(endpoint: "/\(mediaType.rawValue)/top_rated", queryItems: [URLQueryItem(name: "page", value: "\(page)")]) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return decoded.results
    }

    public func searchMedia(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard let url = buildURL(endpoint: "/search/multi", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)")
        ]) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return decoded.results.filter { $0.posterPath != nil || $0.backdropPath != nil }
    }

    public func fetchDetail(id: Int, mediaType: MediaType) async throws -> MediaItem {
        guard let url = buildURL(endpoint: "/\(mediaType.rawValue)/\(id)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MediaItem.self, from: data)
    }

    public func fetchSeasonDetail(tvId: Int, seasonNumber: Int) async throws -> SeasonDetail {
        guard let url = buildURL(endpoint: "/tv/\(tvId)/season/\(seasonNumber)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SeasonDetail.self, from: data)
    }

    public func fetchGenres(mediaType: MediaType = .movie) async throws -> [Genre] {
        guard let url = buildURL(endpoint: "/genre/\(mediaType.rawValue)/list") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        struct GenreResponse: Codable {
            let genres: [Genre]
        }
        let decoded = try JSONDecoder().decode(GenreResponse.self, from: data)
        return decoded.genres
    }
}
