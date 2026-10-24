import Foundation

/// Tendances calculées hors de l'app par le script du Mac mini (dossier trends/
/// du dépôt) et lues dans le document Firestore trends/current. Seulement des
/// comptes agrégés : aucun identifiant d'utilisateur.
nonisolated struct Trends: Codable, Equatable, Sendable {
    /// Moment de la dernière exécution du script (horodatage du serveur).
    let updatedAt: Date
    let userCount: Int
    /// Séries les plus suivies, en ordre décroissant (au plus 100).
    let mostFollowed: [FollowedEntry]
    /// Séries dont le nombre d'abonnés a le plus monté sur risingDays jours.
    /// Seulement des hausses (au plus 100).
    let rising: [RisingEntry]
    /// Fenêtre de comparaison de rising, en jours.
    let risingDays: Int
    /// Date (AAAA-MM-JJ) de la photo de comparaison ; nil avec la méthode addedAt.
    let risingSince: String?
    let risingMethod: RisingMethod

    nonisolated struct FollowedEntry: Codable, Equatable, Hashable, Sendable {
        /// Identifiant TMDB, en texte comme dans followedShows.
        let showID: String
        let url: URL?
        let followers: Int

        var tmdbID: Int? { Int(showID) }
    }

    nonisolated struct RisingEntry: Codable, Equatable, Hashable, Sendable {
        let showID: String
        let url: URL?
        /// Variation nette des abonnés sur la fenêtre (retraits inclus).
        let gained: Int

        var tmdbID: Int? { Int(showID) }
    }

    nonisolated enum RisingMethod: String, Codable, Sendable {
        /// Abonnés d'aujourd'hui moins ceux d'une photo quotidienne plus ancienne.
        case snapshot
        /// Repli tant qu'aucune photo n'est assez ancienne : ajouts datés de la fenêtre.
        case addedAt
    }
}
