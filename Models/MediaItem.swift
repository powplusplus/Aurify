import Foundation

public enum MediaType: String, Codable, CaseIterable, Identifiable {
    case movie = "movie"
    case tv = "tv"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .movie: return "Movies"
        case .tv: return "TV Series"
        }
    }
}

public struct Genre: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

public struct MediaItem: Identifiable, Codable, Hashable {
    public let id: Int
    public let title: String
    public let originalTitle: String?
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let mediaType: MediaType
    public let voteAverage: Double
    public let voteCount: Int
    public let releaseDate: String?
    public let firstAirDate: String?
    public let genreIds: [Int]?
    public let genres: [Genre]?
    public let numberOfSeasons: Int?
    public let numberOfEpisodes: Int?
    public let runtime: Int?
    public let tagline: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case originalTitle = "original_title"
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case mediaType = "media_type"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIds = "genre_ids"
        case genres
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case runtime
        case tagline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        
        let rawTitle = try? container.decode(String.self, forKey: .title)
        let rawName = try? container.decode(String.self, forKey: .name)
        self.title = rawTitle ?? rawName ?? "Untitled"
        
        let rawOrigTitle = try? container.decode(String.self, forKey: .originalTitle)
        let rawOrigName = try? container.decode(String.self, forKey: .originalName)
        self.originalTitle = rawOrigTitle ?? rawOrigName
        
        self.overview = (try? container.decode(String.self, forKey: .overview)) ?? ""
        self.posterPath = try? container.decode(String.self, forKey: .posterPath)
        self.backdropPath = try? container.decode(String.self, forKey: .backdropPath)
        
        if let type = try? container.decode(MediaType.self, forKey: .mediaType) {
            self.mediaType = type
        } else if container.contains(.firstAirDate) || container.contains(.numberOfSeasons) {
            self.mediaType = .tv
        } else {
            self.mediaType = .movie
        }
        
        self.voteAverage = (try? container.decode(Double.self, forKey: .voteAverage)) ?? 0.0
        self.voteCount = (try? container.decode(Int.self, forKey: .voteCount)) ?? 0
        self.releaseDate = try? container.decode(String.self, forKey: .releaseDate)
        self.firstAirDate = try? container.decode(String.self, forKey: .firstAirDate)
        self.genreIds = try? container.decode([Int].self, forKey: .genreIds)
        self.genres = try? container.decode([Genre].self, forKey: .genres)
        self.numberOfSeasons = try? container.decode(Int.self, forKey: .numberOfSeasons)
        self.numberOfEpisodes = try? container.decode(Int.self, forKey: .numberOfEpisodes)
        self.runtime = try? container.decode(Int.self, forKey: .runtime)
        self.tagline = try? container.decode(String.self, forKey: .tagline)
    }

    public init(
        id: Int,
        title: String,
        originalTitle: String? = nil,
        overview: String,
        posterPath: String?,
        backdropPath: String?,
        mediaType: MediaType,
        voteAverage: Double,
        voteCount: Int = 0,
        releaseDate: String? = nil,
        firstAirDate: String? = nil,
        genreIds: [Int]? = nil,
        genres: [Genre]? = nil,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil,
        runtime: Int? = nil,
        tagline: String? = nil
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.mediaType = mediaType
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.releaseDate = releaseDate
        self.firstAirDate = firstAirDate
        self.genreIds = genreIds
        self.genres = genres
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
        self.runtime = runtime
        self.tagline = tagline
    }
    
    public var displayDate: String {
        if let rel = releaseDate, !rel.isEmpty { return String(rel.prefix(4)) }
        if let first = firstAirDate, !first.isEmpty { return String(first.prefix(4)) }
        return "N/A"
    }

    public var fullPosterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    public var fullBackdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
    }
}

public struct TMDBResponse: Codable {
    public let page: Int
    public let results: [MediaItem]
    public let totalPages: Int
    public let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}
