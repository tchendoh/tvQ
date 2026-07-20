import Foundation

/// Entité métier représentant une série suivie ou consultable.
/// Agrège les données pertinentes provenant de TMDB (métadonnées, images)
/// et de TVmaze (horaire), sans exposer la provenance à l'extérieur de la couche Data.
nonisolated struct Show: Identifiable, Equatable, Hashable, Codable {
    /// Identifiant TMDB — clé primaire de l'entité. Garanti présent pour toute
    /// série connue de TMDB, contrairement à l'IMDB ID qui est parfois absent.
    let tmdbID: Int

    /// Identifiant technique interne, dérivé du TMDB ID.
    var id: String { String(tmdbID) }

    /// Identifiant IMDB, utilisé uniquement pour résoudre TVmaze. Optionnel :
    /// certaines séries n'ont pas cet identifiant renseigné sur TMDB, auquel cas
    /// la série reste utilisable mais sans horaire précis TVmaze (repli sur TMDB).
    let imdbID: String?

    /// Identifiant TVmaze, source de l'horaire. Optionnel : soit l'IMDB ID est
    /// absent, soit TVmaze n'a pas de série correspondante.
    let tvmazeID: Int?

    let title: String
    let overview: String
    let posterURL: URL?
    let backdropURL: URL?
    let genres: [String]
    let network: String?
    let status: ShowStatus
    let numberOfSeasons: Int

    /// Code ISO de la langue d'origine de la série (ex. "en", "ja") — utilisé pour
    /// re-fetcher les épisodes dans cette langue si l'utilisateur le préfère.
    let originalLanguage: String
}

nonisolated enum ShowStatus: Equatable, Hashable, Codable {
    case running
    case ended
    case upcoming
    case unknown
}
