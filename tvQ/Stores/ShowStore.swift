import Foundation
import SwiftData

/// Persistance locale des métadonnées de série. Ne retourne que des `Show` (jamais
/// d'entité SwiftData) et ne décide pas de la fraîcheur : voir ShowRepository.
@ModelActor
actor ShowStore {
    nonisolated static let shared = ShowStore(modelContainer: LocalDatabase.container)

    func entry(cacheKey: String) throws -> Cached<Show>? {
        guard let entity = try fetchEntity(cacheKey: cacheKey),
              let show = try? JSONDecoder().decode(Show.self, from: entity.payload) else {
            return nil
        }
        return Cached(value: show, syncedAt: entity.syncedAt)
    }

    func save(_ show: Show, cacheKey: String, syncedAt: Date = .now) throws {
        let payload = try JSONEncoder().encode(show)
        if let existing = try fetchEntity(cacheKey: cacheKey) {
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
    }

    /// Bouton "Clear local cache" de Settings.
    func clear() throws {
        try modelContext.delete(model: ShowEntity.self)
        try modelContext.save()
    }

    private func fetchEntity(cacheKey: String) throws -> ShowEntity? {
        let descriptor = FetchDescriptor<ShowEntity>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try modelContext.fetch(descriptor).first
    }
}
