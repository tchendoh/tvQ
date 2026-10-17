import Foundation

/// Reflète un élément de `GET /3/search/tv` — forme plus légère que TMDBShowDTO
/// (pas de genres complets, pas de external_ids). On complète via fetchShowDetails
/// une fois l'utilisateur a choisi un résultat de recherche.
struct TMDBSearchResultDTO: Codable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    /// Identifiants de genres TMDB. Optionnel par prudence : absent de certaines réponses.
    let genreIDs: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case genreIDs = "genre_ids"
    }
}

struct TMDBSearchResponseDTO: Codable {
    let results: [TMDBSearchResultDTO]
}

/// Reflète `GET /3/tv/{series_id}/season/{season_number}`.
struct TMDBSeasonResponseDTO: Codable {
    let episodes: [TMDBEpisodeDTO]
}
