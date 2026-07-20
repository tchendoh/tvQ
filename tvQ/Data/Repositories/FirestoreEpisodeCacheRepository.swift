import Foundation
import FirebaseFirestore

/// Palier 2 du cache d'épisodes : partagé entre tous les utilisateurs de tvQ.
/// Les épisodes d'une série (titres, dates de diffusion) sont les mêmes pour
/// tout le monde — ce n'est pas une donnée personnelle. Sans ce palier, chaque
/// utilisateur suivant la même série populaire refait le même appel TMDB/TVmaze,
/// ce qui devient le vrai goulot d'étranglement (limites de taux) à l'échelle,
/// bien avant que la latence individuelle ne pose problème.
///
/// Collection `showsCache/{tmdbID}` — voir BACKLOG.md pour la note sur les
/// règles de sécurité Firestore (actuellement lecture+écriture ouvertes à tout
/// utilisateur authentifié ; à revisiter avec une Cloud Function si l'app grossit).
final class FirestoreEpisodeCacheRepository {
    /// Plus long que le cache local (6h) : ce palier absorbe la charge entre
    /// *tous* les utilisateurs, pas juste un appareil — une fraîcheur de 24h
    /// suffit largement pour un horaire de diffusion.
    nonisolated static let ttl: TimeInterval = 60 * 60 * 24 // 24h

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func document(showID: String) -> DocumentReference {
        db.collection("showsCache").document(showID)
    }

    /// nil si absent ou périmé. `maxAge: nil` désactive toute expiration — voir
    /// LocalEpisodeCache.episodes(showID:maxAge:) pour le raisonnement complet
    /// (séries .ended, dont les épisodes ne changeront plus jamais).
    func episodes(showID: String, maxAge: TimeInterval? = FirestoreEpisodeCacheRepository.ttl) async throws -> [Episode]? {
        let snapshot = try await document(showID: showID).getDocument()
        guard snapshot.exists, let entry = try? snapshot.data(as: FirestoreEpisodeCacheEntry.self) else {
            return nil
        }
        if let maxAge {
            guard Date().timeIntervalSince(entry.syncedAt) < maxAge else { return nil }
        }
        return entry.episodes
    }

    func store(showID: String, episodes: [Episode], syncedAt: Date = Date()) async throws {
        let entry = FirestoreEpisodeCacheEntry(episodes: episodes, syncedAt: syncedAt)
        try document(showID: showID).setData(from: entry)
    }
}

private struct FirestoreEpisodeCacheEntry: Codable {
    let episodes: [Episode]
    let syncedAt: Date
}
