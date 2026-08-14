import Foundation

/// Implémentation concrète de ScheduleRepository : combine les épisodes TMDB
/// (source de vérité pour le contenu — titres, synopsis, saisons) avec les
/// timestamps précis de TVmaze quand la série y est résolue.
///
/// Trois paliers de cache, du plus rapide/étroit au plus lent/large :
///   1. `localCache` — disque, par appareil, TTL 6h.
///   2. `sharedCache` — Firestore, partagé entre tous les utilisateurs, TTL 24h.
///   3. TMDB/TVmaze — seulement sollicités si les deux paliers précédents sont périmés.
/// Voir BACKLOG.md pour la discussion complète sur ce choix d'architecture.
final class RemoteScheduleRepository: ScheduleRepository {
    private let tmdbClient: TMDBClient
    private let tvmazeClient: TVmazeClient
    private let localCache: LocalEpisodeCache
    private let sharedCache: FirestoreEpisodeCacheRepository

    init(
        tmdbClient: TMDBClient = TMDBClient(),
        tvmazeClient: TVmazeClient = TVmazeClient(),
        localCache: LocalEpisodeCache = .shared,
        sharedCache: FirestoreEpisodeCacheRepository = FirestoreEpisodeCacheRepository()
    ) {
        self.tmdbClient = tmdbClient
        self.tvmazeClient = tvmazeClient
        self.localCache = localCache
        self.sharedCache = sharedCache
    }

    func getEpisodes(for show: Show) async throws -> [Episode] {
        try await getEpisodesWithTier(for: show).episodes
    }

    private func getEpisodesWithTier(for show: Show) async throws -> (episodes: [Episode], tier: CacheTier) {
        // La clé inclut la langue effective : le cache partagé Firestore est
        // commun à tous les utilisateurs, et le contenu (titres, synopsis) est
        // localisé — sans ça, deux utilisateurs avec des langues différentes
        // s'écraseraient mutuellement le cache. Voir AppSettings.cacheLanguageKey.
        let cacheKey = "\(show.id)_\(AppSettings.cacheLanguageKey)"

        // Une série .ended ne produira plus jamais de nouvel épisode : une fois
        // en cache, ses épisodes restent valides indéfiniment (maxAge: nil),
        // sur les deux paliers — pas seulement pour l'horaire, aussi pour
        // ShowDetailView, qui appelle cette même méthode.
        let maxAge: TimeInterval? = show.status == .ended ? nil : LocalEpisodeCache.ttl
        let sharedMaxAge: TimeInterval? = show.status == .ended ? nil : FirestoreEpisodeCacheRepository.ttl

        if let cached = await localCache.episodes(showID: cacheKey, maxAge: maxAge) {
            return (cached, .local)
        }

        if let cached = try? await sharedCache.episodes(showID: cacheKey, maxAge: sharedMaxAge) {
            await localCache.store(showID: cacheKey, episodes: cached)
            return (cached, .shared)
        }

        let episodes = try await fetchEpisodes(for: show)

        // Écriture best-effort dans le cache partagé : un échec ici (offline,
        // règles Firestore, etc.) ne doit pas empêcher de retourner le résultat
        // déjà obtenu depuis TMDB/TVmaze à l'utilisateur courant.
        try? await sharedCache.store(showID: cacheKey, episodes: episodes)
        await localCache.store(showID: cacheKey, episodes: episodes)

        return (episodes, .remote)
    }

    /// Appel direct aux APIs externes, sans passer par aucun des deux caches —
    /// utilisé uniquement par getEpisodes(for:) une fois les deux paliers vérifiés.
    private func fetchEpisodes(for show: Show) async throws -> [Episode] {
        // Même logique que ShowRepository.getShow — voir discussion sur la langue d'origine.
        let episodeLanguage = AppSettings.useOriginalLanguage ? show.originalLanguage : nil

        // TMDB : un appel par saison, il n'y a pas d'endpoint "tous les épisodes" en un coup.
        var tmdbEpisodes: [TMDBEpisodeDTO] = []
        for season in 1...max(show.numberOfSeasons, 1) {
            let episodes = try await tmdbClient.fetchEpisodes(seriesID: show.tmdbID, season: season, language: episodeLanguage)
            tmdbEpisodes.append(contentsOf: episodes)
        }

        // TVmaze : un seul appel retourne tous les épisodes de toutes les saisons.
        var tvmazeEpisodes: [TVmazeEpisodeDTO] = []
        if let tvmazeID = show.tvmazeID {
            tvmazeEpisodes = try await tvmazeClient.fetchEpisodes(showID: tvmazeID)
        }

        return tmdbEpisodes.map { tmdbEpisode in
            let matchingTVmazeEpisode = tvmazeEpisodes.first {
                $0.season == tmdbEpisode.seasonNumber && $0.number == tmdbEpisode.episodeNumber
            }
            return EpisodeMapper.map(tmdb: tmdbEpisode, tvmaze: matchingTVmazeEpisode, showID: show.id)
        }
    }

    /// "À venir" inclut aussi les épisodes récemment diffusés (jusqu'à 7 jours
    /// en arrière) — pas seulement le futur — pour qu'un épisode sorti hier ou
    /// cette semaine reste visible même si l'utilisateur n'a pas ouvert l'app
    /// le jour même.
    private static let recentlyAiredWindow: TimeInterval = 60 * 60 * 24 * 7 // 7 jours

    func getUpcomingEpisodes(for shows: [Show]) async throws -> [Episode] {
        try await getUpcomingEpisodesWithTiers(for: shows).episodes
    }

    func getUpcomingEpisodesWithTiers(for shows: [Show]) async throws -> (episodes: [Episode], tiers: ScheduleLoadMetrics.TierBreakdown) {
        let now = Date()
        let earliestRelevantDate = now.addingTimeInterval(-Self.recentlyAiredWindow)

        // Une série .ended n'aura plus jamais de nouvel épisode : inutile de la
        // requêter pour l'horaire "à venir" (voir BACKLOG.md).
        let relevantShows = shows.filter { $0.status != .ended }

        // Récupération en parallèle plutôt que séquentielle : chaque appel passe
        // par getEpisodesWithTier(for:), qui sert depuis le cache local ou
        // Firestore avant de retomber sur TMDB/TVmaze.
        let results = try await withThrowingTaskGroup(of: (episodes: [Episode], tier: CacheTier).self) { group in
            for show in relevantShows {
                group.addTask { try await self.getEpisodesWithTier(for: show) }
            }

            var results: [(episodes: [Episode], tier: CacheTier)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        var tiers = ScheduleLoadMetrics.TierBreakdown()
        var allUpcoming: [Episode] = []
        for result in results {
            tiers.record(result.tier)
            allUpcoming.append(contentsOf: result.episodes)
        }

        let upcoming = allUpcoming.filter { episode in
            guard let date = episode.bestAvailableDate else { return false }
            return date >= earliestRelevantDate
        }

        let sorted = upcoming.sorted { lhs, rhs in
            (lhs.bestAvailableDate ?? .distantFuture) < (rhs.bestAvailableDate ?? .distantFuture)
        }

        return (sorted, tiers)
    }
}
