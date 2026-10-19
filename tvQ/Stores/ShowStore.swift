import Foundation
import SwiftData

/// Persistance locale des métadonnées de série. Ne retourne que des `Show` (jamais
/// d'entité SwiftData) et ne décide pas de la fraîcheur : voir ShowRepository.
@ModelActor
actor ShowStore {
    nonisolated static let shared = ShowStore(modelContainer: LocalDatabase.container)

    func entry(cacheKey: String) throws -> Cached<Show>? {
        guard let entity = try fetchEntity(cacheKey: cacheKey) else { return nil }
        guard let show = try? JSONDecoder().decode(Show.self, from: entity.payload) else {
            Log.data.notice("Série locale \(cacheKey) illisible, ignorée")
            return nil
        }
        return Cached(value: show, syncedAt: entity.syncedAt)
    }

    func save(_ show: Show, cacheKey: String, syncedAt: Date = .now) throws {
        let payload = try JSONEncoder().encode(show)
        if let existing = try fetchEntity(cacheKey: cacheKey) {
            // Série identique à celle en place : seule la date change, sans relire l'écran.
            if let current = try? JSONDecoder().decode(Show.self, from: existing.payload), current == show {
                existing.syncedAt = syncedAt
                try modelContext.save()
                return
            }
            existing.payload = payload
            existing.isEnded = show.status == .ended
            existing.syncedAt = syncedAt
        } else {
            modelContext.insert(ShowEntity(
                cacheKey: cacheKey,
                payload: payload,
                isEnded: show.status == .ended,
                syncedAt: syncedAt
            ))
        }
        try modelContext.save()
        LocalDataVersion.bumpFromStore()
    }

    /// Bouton "Clear local cache" de Settings.
    func clear() throws {
        try modelContext.delete(model: ShowEntity.self)
        try modelContext.save()
        LocalDataVersion.bumpFromStore()
    }

    private func fetchEntity(cacheKey: String) throws -> ShowEntity? {
        let descriptor = FetchDescriptor<ShowEntity>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try modelContext.fetch(descriptor).first
    }
}
