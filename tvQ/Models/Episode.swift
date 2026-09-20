import Foundation

/// Entité métier représentant un épisode.
/// `airDate` provient de TMDB (date seule, toujours disponible en fallback).
/// `airStamp` provient de TVmaze quand disponible (date + heure précise, timezone incluse).
nonisolated struct Episode: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let showID: String
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let overview: String
    let stillImageURL: URL?

    /// Date de diffusion, sans heure garantie. Toujours présente si l'épisode est daté.
    let airDate: Date?

    /// Timestamp précis de diffusion (TVmaze), nil si non résolu ou pas encore connu.
    let airStamp: Date?

    /// Meilleure estimation disponible pour l'affichage : airStamp si présent, sinon airDate.
    var bestAvailableDate: Date? {
        airStamp ?? airDate
    }
}
