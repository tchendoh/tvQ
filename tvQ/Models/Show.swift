import Foundation

/// Entité métier représentant une série suivie ou consultable.
/// Agrège les données pertinentes provenant de TMDB (métadonnées, images)
/// et de TVmaze (horaire), sans exposer la provenance : ShowMapper fait la fusion.
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

    /// Couleur dominante de l'image de fond (ou de l'affiche), calculée une fois par
    /// ShowRepository puis gardée avec la série dans toutes les copies (SwiftData,
    /// Firestore). nil tant qu'elle n'est pas calculée, ou sans image.
    /// `var` avec valeur par défaut : absente des anciennes copies en cache, qui
    /// se décodent quand même (champ optionnel).
    var dominantColor: ShowColor? = nil
    /// Deuxième couleur de l'image, déjà rendue lisible sur fond sombre (détails de
    /// la Live Activity). nil si l'image n'a qu'une couleur, ou pas encore calculée.
    var accentColor: ShowColor? = nil

    /// Applique les couleurs calculées (voir ShowColorExtractor).
    mutating func apply(_ palette: ShowPalette?) {
        dominantColor = palette?.dominant
        accentColor = palette?.accent
    }
}

nonisolated enum ShowStatus: Equatable, Hashable, Codable {
    case running
    case ended
    case upcoming
    case unknown
}
