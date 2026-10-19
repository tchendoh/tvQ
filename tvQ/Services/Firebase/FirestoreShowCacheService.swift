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
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await document(cacheKey: cacheKey).getDocument()
        } catch {
            // Le repository ignore les erreurs de cache (try?) : sans ceci, un
            // dépassement de quota passerait inaperçu.
            FirestoreQuota.recordIfExceeded(error)
            Log.data.error("Lecture showMetadataCache/\(cacheKey) échouée", error)
            throw error
        }
        guard snapshot.exists else { return nil }
        guard let entry = try? snapshot.data(as: FirestoreShowCacheEntry.self) else {
            // Format d'une autre version de l'app : on retombe sur les API et on réécrit.
            Log.data.notice("Document showMetadataCache/\(cacheKey) illisible, ignoré")
            return nil
        }
        return Cached(value: entry.show, syncedAt: entry.syncedAt)
    }

    func store(cacheKey: String, show: Show, syncedAt: Date = .now) async throws {
        let entry = FirestoreShowCacheEntry(show: show, syncedAt: syncedAt)
        try document(cacheKey: cacheKey).setData(from: entry) { error in
            Self.logWriteError(error, path: "showMetadataCache/\(cacheKey)")
        }
    }

    /// L'écriture part sans attendre : le serveur répond plus tard (ou au retour du
    /// réseau). Sans cette fonction de rappel, un refus des règles Firestore ou un
    /// dépassement de quota passerait complètement inaperçu.
    nonisolated static func logWriteError(_ error: Error?, path: String) {
        guard let error else { return }
        Log.data.error("Écriture \(path) refusée", error, report: true)
    }
}

private struct FirestoreShowCacheEntry: Codable {
    let show: Show
    let syncedAt: Date
}
