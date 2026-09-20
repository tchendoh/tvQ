import Foundation
import SwiftData

/// Date de dernière synchronisation de la liste d'épisodes d'une série (par `cacheKey`).
/// Séparée des épisodes eux-mêmes pour qu'une série sans aucun épisode connu ait
/// quand même une fraîcheur, et pour ne pas répéter la date sur chaque ligne.
@Model
nonisolated final class EpisodeSyncEntity {
    @Attribute(.unique) var cacheKey: String
    var syncedAt: Date

    init(cacheKey: String, syncedAt: Date) {
        self.cacheKey = cacheKey
        self.syncedAt = syncedAt
    }
}
