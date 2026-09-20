import Foundation
import FirebaseFirestore

/// Cache d'épisodes partagé entre tous les utilisateurs de tvQ.
/// Les épisodes d'une série (titres, dates de diffusion) sont les mêmes pour
/// tout le monde — ce n'est pas une donnée personnelle. Sans ce cache, chaque
/// utilisateur suivant la même série populaire refait le même appel TMDB/TVmaze,
/// ce qui devient le vrai goulot d'étranglement (limites de taux) à l'échelle,
/// bien avant que la latence individuelle ne pose problème.
///
/// Ce service ne juge pas de la fraîcheur : il retourne la donnée avec sa date de
/// synchronisation et le repository décide (voir CachePolicy).
///
/// Collection `showsCache/{cacheKey}`. Note de sécurité : les règles Firestore
/// donnent actuellement lecture et écriture à tout utilisateur authentifié ;
/// à revisiter avec une Cloud Function si l'app grossit.
final class FirestoreEpisodeCacheService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func document(cacheKey: String) -> DocumentReference {
        db.collection("showsCache").document(cacheKey)
    }

    /// nil si absent ou dans un format illisible (ancienne version de l'app, par exemple) :
    /// dans les deux cas le repository retombe sur TMDB/TVmaze et réécrit le document.
    func episodes(cacheKey: String) async throws -> Cached<[Episode]>? {
        let snapshot = try await document(cacheKey: cacheKey).getDocument()
        guard snapshot.exists, let entry = try? snapshot.data(as: FirestoreEpisodeCacheEntry.self) else {
            return nil
        }
        return Cached(value: entry.episodes, syncedAt: entry.syncedAt)
    }

    func store(cacheKey: String, episodes: [Episode], syncedAt: Date = .now) async throws {
        let entry = FirestoreEpisodeCacheEntry(episodes: episodes, syncedAt: syncedAt)
        try document(cacheKey: cacheKey).setData(from: entry)
    }
}

private struct FirestoreEpisodeCacheEntry: Codable {
    let episodes: [Episode]
    let syncedAt: Date
}
