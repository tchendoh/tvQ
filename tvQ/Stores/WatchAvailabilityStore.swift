import Foundation
import SwiftData

/// Persistance locale de la disponibilité de visionnement. Pas de cache partagé
/// Firestore pour celle-ci : la donnée dépend de la région choisie par l'utilisateur,
/// donc elle se réutilise peu d'un utilisateur à l'autre.
@ModelActor
actor WatchAvailabilityStore {
    nonisolated static let shared = WatchAvailabilityStore(modelContainer: LocalDatabase.container)

    func entry(cacheKey: String) throws -> Cached<WatchAvailability>? {
        guard let entity = try fetchEntity(cacheKey: cacheKey),
              let availability = try? JSONDecoder().decode(WatchAvailability.self, from: entity.payload) else {
            return nil
        }
        return Cached(value: availability, syncedAt: entity.syncedAt)
    }

    func save(_ availability: WatchAvailability, cacheKey: String, syncedAt: Date = .now) throws {
        let payload = try JSONEncoder().encode(availability)
        if let existing = try fetchEntity(cacheKey: cacheKey) {
            existing.payload = payload
            existing.syncedAt = syncedAt
        } else {
            modelContext.insert(WatchAvailabilityEntity(cacheKey: cacheKey, payload: payload, syncedAt: syncedAt))
        }
        try modelContext.save()
    }

    func clear() throws {
        try modelContext.delete(model: WatchAvailabilityEntity.self)
        try modelContext.save()
    }

    private func fetchEntity(cacheKey: String) throws -> WatchAvailabilityEntity? {
        let descriptor = FetchDescriptor<WatchAvailabilityEntity>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try modelContext.fetch(descriptor).first
    }
}
