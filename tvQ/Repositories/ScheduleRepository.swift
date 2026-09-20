import Foundation

/// Repository des épisodes : combine les épisodes TMDB
/// (source de vérité pour le contenu — titres, synopsis, saisons) avec les
/// timestamps précis de TVmaze quand la série y est résolue.
///
/// Lecture en cascade : copie locale (EpisodeStore, SwiftData), puis copie partagée
/// (Firestore), puis TMDB/TVmaze. Une copie locale périmée est retournée quand même
/// et rafraîchie en arrière-plan. La liste « à venir » n'est plus construite en
/// chargeant tous les épisodes de chaque série : elle est lue d'un seul coup dans le
/// store par une requête sur la date (voir getUpcomingEpisodesWithTiers).
final class ScheduleRepository {
    private let tmdbService: TMDBService
    private let tvmazeService: TVmazeService
    private let episodeStore: EpisodeStore
    private let sharedCache: FirestoreEpisodeCacheService

    /// Résolutions distantes déjà en cours, par clé de cache : deux écrans qui demandent
    /// la même série en même temps partagent un seul appel au lieu de le doubler.
    private var inFlight: [String: Task<(episodes: [Episode], tier: CacheTier), Error>] = [:]

    init(
        tmdbService: TMDBService = TMDBService(),
        tvmazeService: TVmazeService = TVmazeService(),
        episodeStore: EpisodeStore = .shared,
        sharedCache: FirestoreEpisodeCacheService = FirestoreEpisodeCacheService()
    ) {
        self.tmdbService = tmdbService
        self.tvmazeService = tvmazeService
        self.episodeStore = episodeStore
        self.sharedCache = sharedCache
    }

    /// La clé inclut la langue effective : la copie Firestore est commune à tous les
    /// utilisateurs et le contenu (titres, synopsis) est localisé. Voir AppSettings.cacheLanguageKey.
    private func cacheKey(for show: Show) -> String {
        "\(show.id)_\(AppSettings.cacheLanguageKey)"
    }

    // MARK: - Épisodes d'une série

    func getEpisodes(for show: Show) async throws -> [Episode] {
        let cacheKey = cacheKey(for: show)

        if let local = try? await episodeStore.entry(cacheKey: cacheKey) {
            refreshInBackgroundIfStale(show: show, cacheKey: cacheKey, syncedAt: local.syncedAt)
            return local.value
        }

        return try await resolveRemotely(show: show, cacheKey: cacheKey).episodes
    }

    /// Vérifie qu'une série a des épisodes en local, sans les décoder : c'est tout ce dont
    /// l'écran Schedule a besoin avant de faire sa requête groupée. Ne charge depuis le réseau
    /// que si la série n'a jamais été synchronisée.
    private func ensureEpisodes(for show: Show) async throws -> CacheTier {
        let cacheKey = cacheKey(for: show)

        if let syncedAt = try? await episodeStore.syncedAt(cacheKey: cacheKey) {
            refreshInBackgroundIfStale(show: show, cacheKey: cacheKey, syncedAt: syncedAt)
            return .local
        }

        return try await resolveRemotely(show: show, cacheKey: cacheKey).tier
    }

    /// Une série terminée ne produira plus jamais de nouvel épisode : sa copie ne périme pas.
    private func refreshInBackgroundIfStale(show: Show, cacheKey: String, syncedAt: Date) {
        guard !CachePolicy.local.isFresh(syncedAt: syncedAt, isEnded: show.status == .ended) else { return }
        Task { _ = try? await self.resolveRemotely(show: show, cacheKey: cacheKey) }
    }

    /// Copie partagée puis TMDB/TVmaze, avec écriture dans les deux copies.
    private func resolveRemotely(show: Show, cacheKey: String) async throws -> (episodes: [Episode], tier: CacheTier) {
        if let task = inFlight[cacheKey] {
            return try await task.value
        }

        let task = Task { try await self.loadFromSharedOrRemote(show: show, cacheKey: cacheKey) }
        inFlight[cacheKey] = task
        defer { inFlight[cacheKey] = nil }
        return try await task.value
    }

    private func loadFromSharedOrRemote(show: Show, cacheKey: String) async throws -> (episodes: [Episode], tier: CacheTier) {
        if let shared = try? await sharedCache.episodes(cacheKey: cacheKey),
           CachePolicy.shared.isFresh(syncedAt: shared.syncedAt, isEnded: show.status == .ended) {
            // On garde la date d'origine : une copie déjà vieille ne redevient pas "fraîche".
            try? await episodeStore.save(shared.value, cacheKey: cacheKey, syncedAt: shared.syncedAt)
            return (shared.value, .shared)
        }

        let episodes = try await fetchEpisodes(for: show)
        let now = Date.now

        // Écriture best-effort dans la copie partagée : un échec (hors ligne, règles
        // Firestore) ne doit pas empêcher de retourner le résultat à l'utilisateur.
        try? await sharedCache.store(cacheKey: cacheKey, episodes: episodes, syncedAt: now)
        try? await episodeStore.save(episodes, cacheKey: cacheKey, syncedAt: now)
        return (episodes, .remote)
    }

    /// Appel direct aux APIs externes, sans passer par aucun cache.
    private func fetchEpisodes(for show: Show) async throws -> [Episode] {
        // Même logique que ShowRepository.getShow pour la langue d'origine.
        let episodeLanguage = AppSettings.useOriginalLanguage ? show.originalLanguage : nil

        // TMDB : un appel par saison, il n'y a pas d'endpoint "tous les épisodes" en un coup.
        var tmdbEpisodes: [TMDBEpisodeDTO] = []
        for season in 1...max(show.numberOfSeasons, 1) {
            let episodes = try await tmdbService.fetchEpisodes(seriesID: show.tmdbID, season: season, language: episodeLanguage)
            tmdbEpisodes.append(contentsOf: episodes)
        }

        // TVmaze : un seul appel retourne tous les épisodes de toutes les saisons.
        var tvmazeEpisodes: [TVmazeEpisodeDTO] = []
        if let tvmazeID = show.tvmazeID {
            tvmazeEpisodes = try await tvmazeService.fetchEpisodes(showID: tvmazeID)
        }

        // Index (saison, numéro) pour la jointure TMDB/TVmaze en O(n) plutôt qu'O(n·m).
        struct EpisodeKey: Hashable { let season: Int; let number: Int }
        let tvmazeByKey = Dictionary(
            tvmazeEpisodes.compactMap { episode in
                episode.number.map { (EpisodeKey(season: episode.season, number: $0), episode) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        return tmdbEpisodes.map { tmdbEpisode in
            let key = EpisodeKey(season: tmdbEpisode.seasonNumber, number: tmdbEpisode.episodeNumber)
            return EpisodeMapper.map(tmdb: tmdbEpisode, tvmaze: tvmazeByKey[key], showID: show.id)
        }
    }

    // MARK: - Horaire "à venir"

    /// "À venir" inclut aussi les épisodes récemment diffusés (jusqu'à 7 jours
    /// en arrière) — pas seulement le futur — pour qu'un épisode sorti hier ou
    /// cette semaine reste visible même si l'utilisateur n'a pas ouvert l'app
    /// le jour même.
    private static let recentlyAiredWindow: TimeInterval = 60 * 60 * 24 * 7 // 7 jours

    func getUpcomingEpisodes(for shows: [Show]) async throws -> [Episode] {
        try await getUpcomingEpisodesWithTiers(for: shows).episodes
    }

    func getUpcomingEpisodesWithTiers(for shows: [Show]) async throws -> (episodes: [Episode], tiers: ScheduleLoadMetrics.TierBreakdown) {
        let earliestRelevantDate = Date.now.addingTimeInterval(-Self.recentlyAiredWindow)

        // Une série .ended n'aura plus jamais de nouvel épisode : inutile de la
        // requêter pour l'horaire "à venir".
        let relevantShows = shows.filter { $0.status != .ended }

        // 1. S'assurer, en parallèle, que chaque série a des épisodes en local.
        let cacheTiers = try await withThrowingTaskGroup(of: CacheTier.self) { group in
            for show in relevantShows {
                group.addTask { try await self.ensureEpisodes(for: show) }
            }

            var results: [CacheTier] = []
            for try await tier in group {
                results.append(tier)
            }
            return results
        }

        var tiers = ScheduleLoadMetrics.TierBreakdown()
        cacheTiers.forEach { tiers.record($0) }

        // 2. Une seule requête, filtrée et triée par date dans le store.
        let cacheKeys = relevantShows.map { cacheKey(for: $0) }
        let upcoming = try await episodeStore.upcoming(cacheKeys: cacheKeys, since: earliestRelevantDate)
        return (upcoming, tiers)
    }
}
