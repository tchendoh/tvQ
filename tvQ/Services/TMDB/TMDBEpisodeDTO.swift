import Foundation

/// Reflète exactement un élément de la réponse JSON de
/// `GET /3/tv/{series_id}/season/{season_number}` (TMDB, champ "episodes").
struct TMDBEpisodeDTO: Codable {
    let id: Int
    let name: String
    let overview: String
    let seasonNumber: Int
    let episodeNumber: Int
    let airDate: String? // format "YYYY-MM-DD", date seule — pas d'heure côté TMDB
    let stillPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
    }
}
