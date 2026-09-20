import Foundation
import FirebaseFirestore

/// Palier 2 du cache de métadonnées de série — même principe que
/// FirestoreEpisodeCacheService (voir ce fichier pour le raisonnement complet
/// sur pourquoi un cache partagé entre utilisateurs). Collection séparée
/// (`showMetadataCache`) plutôt que de réutiliser `showsCache` : structure et
/// TTL différents, pas besoin de les mélanger dans la même collection.
final class FirestoreShowCacheService {
    nonisolated static let ttl: TimeInterval = 60 * 60 * 24 // 24h

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func document(cacheKey: String) -> DocumentReference {
        db.collection("showMetadataCache").document(cacheKey)
    }

    /// nil si absent ou périmé. Comme LocalShowCache : une série dont le statut
    /// caché est déjà .ended ne périme jamais (son statut ne peut plus changer).
    /// Décidé ici plutôt que par l'appelant — contrairement aux épisodes, on n'a
    /// pas encore de Show résolu au moment de consulter ce cache, seulement le
    /// statut qu'on a nous-mêmes stocké lors du dernier passage.
    func show(cacheKey: String) async throws -> Show? {
        let snapshot = try await document(cacheKey: cacheKey).getDocument()
        guard snapshot.exists, let entry = try? snapshot.data(as: FirestoreShowCacheEntry.self) else {
            return nil
        }
        if entry.show.status == .ended { return entry.show }
        guard Date().timeIntervalSince(entry.syncedAt) < Self.ttl else { return nil }
        return entry.show
    }

    func store(cacheKey: String, show: Show, syncedAt: Date = Date()) async throws {
        let entry = FirestoreShowCacheEntry(show: show, syncedAt: syncedAt)
        try document(cacheKey: cacheKey).setData(from: entry)
    }
}

private struct FirestoreShowCacheEntry: Codable {
    let show: Show
    let syncedAt: Date
}
