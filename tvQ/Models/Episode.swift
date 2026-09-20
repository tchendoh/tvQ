import Foundation

/// Entité métier représentant un épisode.
/// `airDate` est la meilleure date de diffusion connue, choisie une fois pour
/// toutes par EpisodeMapper : le timestamp précis de TVmaze (date + heure,
/// timezone incluse) quand il existe, sinon la date seule de TMDB.
/// `hasPreciseTime` indique lequel des deux a été retenu.
nonisolated struct Episode: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let showID: String
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let overview: String
    let stillImageURL: URL?

    /// nil si l'épisode n'est pas encore daté.
    let airDate: Date?

    /// true si `airDate` porte une heure fiable (source TVmaze), false si c'est
    /// une date seule (TMDB) dont l'heure n'a aucune signification.
    let hasPreciseTime: Bool
}
