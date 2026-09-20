import Foundation
import FirebaseFirestore

/// Cache de métadonnées de série partagé entre utilisateurs — même principe que
/// FirestoreEpisodeCacheService (voir ce fichier pour le raisonnement complet).
/// Collection séparée (`showMetadataCache`) plutôt que de réutiliser `showsCache` :
/// structure différente, pas besoin de les mélanger.
///
/// Comme pour les épisodes, la fraîcheur (dont la règle « une série terminée ne
/// périme jamais ») est décidée par le repository, pas ici.
final class FirestoreShowCacheService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func document(cacheKey: String) -> DocumentReference {
        db.collection("showMetadataCache").document(cacheKey)
    }

    func show(cacheKey: String) async throws -> Cached<Show>? {
        let snapshot = try await document(cacheKey: cacheKey).getDocument()
        guard snapshot.exists, let entry = try? snapshot.data(as: FirestoreShowCacheEntry.self) else {
            return nil
        }
        return Cached(value: entry.show, syncedAt: entry.syncedAt)
    }

    func store(cacheKey: String, show: Show, syncedAt: Date = .now) async throws {
        let entry = FirestoreShowCacheEntry(show: show, syncedAt: syncedAt)
        try document(cacheKey: cacheKey).setData(from: entry)
    }
}

private struct FirestoreShowCacheEntry: Codable {
    let show: Show
    let syncedAt: Date
}
