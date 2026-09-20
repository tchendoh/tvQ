import Foundation
import SwiftData

/// Forme persistée d'une `WatchAvailability`, par série et par région
/// (`cacheKey` = tmdbID + région). Lue uniquement par clé : le modèle est stocké
/// en JSON, comme ShowEntity.
@Model
nonisolated final class WatchAvailabilityEntity {
    @Attribute(.unique) var cacheKey: String
    var payload: Data
    var syncedAt: Date

    init(cacheKey: String, payload: Data, syncedAt: Date) {
        self.cacheKey = cacheKey
        self.payload = payload
        self.syncedAt = syncedAt
    }
}
