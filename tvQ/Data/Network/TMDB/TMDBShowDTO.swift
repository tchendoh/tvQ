import Foundation

/// Reflète exactement la réponse JSON de `GET /3/tv/{series_id}` (TMDB).
/// Ne doit contenir aucune logique — seulement le mapping brut du JSON.
struct TMDBShowDTO: Codable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let genres: [TMDBGenreDTO]
    let networks: [TMDBNetworkDTO]
    let status: String
    let numberOfSeasons: Int
    let externalIDs: TMDBExternalIDsDTO?

    /// Toujours retourné par TMDB peu importe le `language` de la requête —
    /// sert à re-fetcher dans la langue d'origine si l'utilisateur le préfère.
    let originalLanguage: String

    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, networks, status
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case numberOfSeasons = "number_of_seasons"
        case externalIDs = "external_ids"
        case originalLanguage = "original_language"
    }
}

struct TMDBGenreDTO: Codable {
    let id: Int
    let name: String
}

struct TMDBNetworkDTO: Codable {
    let id: Int
    let name: String
}

/// Réponse de `GET /3/tv/{series_id}/external_ids` — utilisée pour résoudre
/// l'IMDB ID pivot vers TVmaze. Peut aussi être obtenue via `append_to_response=external_ids`
/// directement sur l'appel de détails, d'où le champ optionnel imbriqué ci-dessus.
struct TMDBExternalIDsDTO: Codable {
    let imdbID: String?
    let tvdbID: Int?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
        case tvdbID = "tvdb_id"
    }
}
