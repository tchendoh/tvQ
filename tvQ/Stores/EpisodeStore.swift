import Foundation
import SwiftData

/// Persistance locale des épisodes. Comme ShowStore, il ne retourne que des modèles
/// (`Episode`) et laisse la politique de fraîcheur au repository.
@ModelActor
actor EpisodeStore {
    nonisolated static let shared = EpisodeStore(modelContainer: LocalDatabase.container)

    /// Date de synchronisation seulement, sans décoder les épisodes : sert à vérifier
    /// la fraîcheur d'une série à peu de frais (voir ScheduleRepository.ensureEpisodes).
    func syncedAt(cacheKey: String) throws -> Date? {
        let descriptor = FetchDescriptor<EpisodeSyncEntity>(predicate: #Predicate { $0.cacheKey == cacheKey })
        return try modelContext.fetch(descriptor).first?.syncedAt
    }

    /// Tous les épisodes d'une série (une langue), triés, avec leur date de synchronisation.
    /// nil si cette série n'a jamais été synchronisée.
    func entry(cacheKey: String) throws -> Cached<[Episode]>? {
        let syncDescriptor = FetchDescriptor<EpisodeSyncEntity>(
            predicate: #Predicate { $0.cacheKey == cacheKey }
        )
        guard let sync = try modelContext.fetch(syncDescriptor).first else { return nil }

        let descriptor = FetchDescriptor<EpisodeEntity>(
            predicate: #Predicate { $0.cacheKey == cacheKey },
            sortBy: [SortDescriptor(\.seasonNumber), SortDescriptor(\.episodeNumber)]
        )
        let episodes = try modelContext.fetch(descriptor).map { $0.toDomain() }
        return Cached(value: episodes, syncedAt: sync.syncedAt)
    }

    /// Remplace tous les épisodes de cette série d'un seul coup (une seule transaction).
    func save(_ episodes: [Episode], cacheKey: String, syncedAt: Date = .now) throws {
        try modelContext.delete(model: EpisodeEntity.self, where: #Predicate { $0.cacheKey == cacheKey })
        try modelContext.delete(model: EpisodeSyncEntity.self, where: #Predicate { $0.cacheKey == cacheKey })

        for episode in episodes {
            modelContext.insert(EpisodeEntity(cacheKey: cacheKey, episode: episode))
        }
        modelContext.insert(EpisodeSyncEntity(cacheKey: cacheKey, syncedAt: syncedAt))
        try modelContext.save()
    }

    /// Épisodes datés à partir de `cutoff`, pour les séries données, triés par date.
    /// C'est la requête de l'écran Schedule : le filtrage se fait dans le store au lieu
    /// de charger tout l'historique de chaque série en mémoire.
    func upcoming(cacheKeys: [String], since cutoff: Date) throws -> [Episode] {
        let floor = Date.distantPast
        let descriptor = FetchDescriptor<EpisodeEntity>(
            predicate: #Predicate { cacheKeys.contains($0.cacheKey) && ($0.airDate ?? floor) >= cutoff }
        )
        return try modelContext.fetch(descriptor)
            .map { $0.toDomain() }
            .sorted { ($0.airDate ?? .distantFuture) < ($1.airDate ?? .distantFuture) }
    }

    /// Bouton "Clear local cache" de Settings.
    func clear() throws {
        try modelContext.delete(model: EpisodeEntity.self)
        try modelContext.delete(model: EpisodeSyncEntity.self)
        try modelContext.save()
    }
}
