import Foundation

public struct Episode: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let overview: String
    public let episodeNumber: Int
    public let seasonNumber: Int
    public let stillPath: String?
    public let airDate: String?
    public let voteAverage: Double?
    public let runtime: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
        case runtime
    }
    
    public init(
        id: Int,
        name: String,
        overview: String,
        episodeNumber: Int,
        seasonNumber: Int,
        stillPath: String? = nil,
        airDate: String? = nil,
        voteAverage: Double? = nil,
        runtime: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.overview = overview
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.stillPath = stillPath
        self.airDate = airDate
        self.voteAverage = voteAverage
        self.runtime = runtime
    }

    public var fullStillURL: URL? {
        guard let path = stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

public struct SeasonDetail: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let overview: String
    public let seasonNumber: Int
    public let posterPath: String?
    public let episodes: [Episode]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
        case episodes
    }
}
