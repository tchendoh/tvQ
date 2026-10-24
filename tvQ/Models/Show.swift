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

    /// Accent à afficher : accentColor, sinon la dominante éclaircie. Même
    /// calcul que la Live Activity (ShowColor.resolvedAccent).
    var resolvedAccentColor: ShowColor? {
        ShowColor.resolvedAccent(accent: accentColor, dominant: dominantColor)
    }

    /// Format selon TVmaze ("Scripted", "Reality", "Game Show"…), nil si TVmaze ne
    /// connaît pas la série. Sert à écarter les jeux quotidiens de Home.
    var tvmazeType: String? = nil
    /// Épisodes de la saison régulière la plus fournie parmi les deux dernières
    /// (TMDB). Repli quand le type TVmaze manque.
    var recentSeasonEpisodeCount: Int? = nil

    /// Version du calcul qui a produit dominantColor et accentColor. Une copie
    /// en cache d'une autre version est recalculée (ShowRepository) : à
    /// incrémenter quand la source ou l'algorithme des couleurs change.
    /// nil : copie antérieure à ce champ (calculée sur l'image de fond).
    var colorVersion: Int? = nil

    /// 2 : couleurs tirées de l'affiche plutôt que de l'image de fond (2026-10-22).
    static let currentColorVersion = 2

    /// Applique les couleurs calculées (voir ShowColorExtractor).
    mutating func apply(_ palette: ShowPalette?) {
        dominantColor = palette?.dominant
        accentColor = palette?.accent
        colorVersion = palette == nil ? nil : Self.currentColorVersion
    }
}

nonisolated enum ShowStatus: Equatable, Hashable, Codable {
    case running
    case ended
    case upcoming
    case unknown
}
