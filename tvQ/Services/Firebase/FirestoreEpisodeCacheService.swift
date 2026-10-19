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
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await document(cacheKey: cacheKey).getDocument()
        } catch {
            // Le repository ignore les erreurs de cache (try?) : sans ceci, un
            // dépassement de quota passerait inaperçu.
            FirestoreQuota.recordIfExceeded(error)
            Log.data.error("Lecture showsCache/\(cacheKey) échouée", error)
            throw error
        }
        guard snapshot.exists else { return nil }
        guard let entry = try? snapshot.data(as: FirestoreEpisodeCacheEntry.self) else {
            // Format d'une autre version de l'app : on retombe sur les API et on réécrit.
            Log.data.notice("Document showsCache/\(cacheKey) illisible, ignoré")
            return nil
        }
        return Cached(value: entry.episodes, syncedAt: entry.syncedAt)
    }

    /// Firestore refuse les documents de plus de 1 Mo, et les règles de sécurité
    /// plafonnent à 2000 épisodes. Une émission quotidienne (ex. The Daily Show,
    /// des milliers d'épisodes, 1,4 Mo) n'entre pas : on ne la partage pas, le
    /// cache local et TMDB/TVmaze suffisent pour ces quelques séries.
    static let maxSharedEpisodes = 1500

    func store(cacheKey: String, episodes: [Episode], syncedAt: Date = .now) async throws {
        guard episodes.count <= Self.maxSharedEpisodes else {
            Log.data.notice("\(cacheKey) : \(episodes.count) épisodes, trop pour le cache partagé")
            return
        }
        let entry = FirestoreEpisodeCacheEntry(episodes: episodes, syncedAt: syncedAt)
        // Fonction de rappel : voir FirestoreShowCacheService.logWriteError.
        try document(cacheKey: cacheKey).setData(from: entry) { error in
            FirestoreShowCacheService.logWriteError(error, path: "showsCache/\(cacheKey)")
        }
    }
}

private struct FirestoreEpisodeCacheEntry: Codable {
    let episodes: [Episode]
    let syncedAt: Date
}
