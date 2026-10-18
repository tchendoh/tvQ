import Foundation

/// Repository des épisodes : combine les épisodes TMDB
/// (source de vérité pour le contenu — titres, synopsis, saisons) avec les
/// timestamps précis de TVmaze quand la série y est résolue.
///
/// Lecture en cascade : copie locale (EpisodeStore, SwiftData), puis copie partagée
/// (Firestore), puis TMDB/TVmaze. Une copie locale périmée est retournée quand même
/// et rafraîchie en arrière-plan. La liste « à venir » n'est plus construite en
/// chargeant tous les épisodes de chaque série : elle est lue d'un seul coup dans le
/// store par une requête sur la date (voir getUpcomingEpisodes).
final class ScheduleRepository {
    /// Instance unique partagée par tous les écrans : c'est ce qui permet à `inFlight`
    /// de dédoublonner les requêtes d'un écran à l'autre. L'`init` reste public
    /// pour injecter une autre instance dans les tests.
    static let shared = ScheduleRepository()

    private let tmdbService: any TMDBFetching
    private let tvmazeService: any TVmazeFetching
    private let episodeStore: EpisodeStore
    private let sharedCache: any SharedEpisodeCaching

    /// Résolutions distantes déjà en cours, par clé de cache : deux écrans qui demandent
    /// la même série en même temps partagent un seul appel au lieu de le doubler.
    private var inFlight: [String: Task<[Episode], Error>] = [:]

    init(
        tmdbService: any TMDBFetching = TMDBService(),
        tvmazeService: any TVmazeFetching = TVmazeService(),
        episodeStore: EpisodeStore = .shared,
        sharedCache: any SharedEpisodeCaching = FirestoreEpisodeCacheService()
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

        return try await resolveRemotely(show: show, cacheKey: cacheKey)
    }

    /// Vérifie qu'une série a des épisodes en local, sans les décoder : c'est tout ce dont
    /// l'écran Schedule a besoin avant de faire sa requête groupée. Ne charge depuis le réseau
    /// que si la série n'a jamais été synchronisée.
    private func ensureEpisodes(for show: Show) async throws {
        let cacheKey = cacheKey(for: show)

        if let syncedAt = try? await episodeStore.syncedAt(cacheKey: cacheKey) {
            refreshInBackgroundIfStale(show: show, cacheKey: cacheKey, syncedAt: syncedAt)
            return
        }

        _ = try await resolveRemotely(show: show, cacheKey: cacheKey)
    }

    /// Une série terminée ne produira plus jamais de nouvel épisode : sa copie ne périme pas.
    private func refreshInBackgroundIfStale(show: Show, cacheKey: String, syncedAt: Date) {
        guard !CachePolicy.local.isFresh(syncedAt: syncedAt, isEnded: show.status == .ended) else { return }
        Task { _ = try? await self.resolveRemotely(show: show, cacheKey: cacheKey) }
    }

    /// Copie partagée puis TMDB/TVmaze, avec écriture dans les deux copies.
    private func resolveRemotely(show: Show, cacheKey: String) async throws -> [Episode] {
        if let task = inFlight[cacheKey] {
            return try await task.value
        }

        let task = Task { try await self.loadFromSharedOrRemote(show: show, cacheKey: cacheKey) }
        inFlight[cacheKey] = task
        defer { inFlight[cacheKey] = nil }
        return try await task.value
    }

    private func loadFromSharedOrRemote(show: Show, cacheKey: String) async throws -> [Episode] {
        if let shared = try? await sharedCache.episodes(cacheKey: cacheKey),
           CachePolicy.shared.isFresh(syncedAt: shared.syncedAt, isEnded: show.status == .ended) {
            // On garde la date d'origine : une copie déjà vieille ne redevient pas "fraîche".
            try? await episodeStore.save(shared.value, cacheKey: cacheKey, syncedAt: shared.syncedAt)
            return shared.value
        }

        let episodes = try await fetchEpisodes(for: show)
        let now = Date.now

        // Écriture best-effort dans la copie partagée : un échec (hors ligne, règles
        // Firestore) ne doit pas empêcher de retourner le résultat à l'utilisateur.
        try? await sharedCache.store(cacheKey: cacheKey, episodes: episodes, syncedAt: now)
        try? await episodeStore.save(episodes, cacheKey: cacheKey, syncedAt: now)
        return episodes
    }

    /// Appel direct aux APIs externes, sans passer par aucun cache.
    private func fetchEpisodes(for show: Show) async throws -> [Episode] {
        // Même logique que ShowRepository.getShow pour la langue d'origine.
        let episodeLanguage = AppSettings.useOriginalLanguage ? show.originalLanguage : nil

        // TMDB : un appel par saison (pas d'endpoint "tous les épisodes"), lancés en
        // parallèle. Seulement les saisons récentes : l'horaire et les notifications
        // n'ont besoin que de la saison en cours, et la fiche charge les plus
        // anciennes à leur ouverture (fetchOlderSeason).
        let seasons = Self.recentSeasons(of: show)
        let tmdbEpisodes = try await withThrowingTaskGroup(of: [TMDBEpisodeDTO].self) { group in
            for season in seasons {
                group.addTask {
                    try await self.fetchTMDBSeason(seriesID: show.tmdbID, season: season, language: episodeLanguage)
                }
            }
            var all: [TMDBEpisodeDTO] = []
            for try await episodes in group {
                all.append(contentsOf: episodes)
            }
            // Les saisons arrivent dans le désordre : on rétablit l'ordre.
            return all.sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
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

    /// Saisons chargées et mises en cache pour chaque série : la saison en cours, la
    /// précédente (rattrapage) et une de marge. Évite de charger les 36 saisons des
    /// Simpson, ou les centaines d'épisodes d'une quotidienne.
    static let recentSeasonCount = 3

    static func recentSeasons(of show: Show) -> [Int] {
        let last = max(show.numberOfSeasons, 1)
        return Array(max(1, last - recentSeasonCount + 1)...last)
    }

    /// Saison plus ancienne, à la demande (fiche, ouverture d'une saison). Sans cache
    /// ni TVmaze : saison terminée, rarement consultée, et son heure exacte de
    /// diffusion n'intéresse plus personne.
    func fetchOlderSeason(_ season: Int, of show: Show) async throws -> [Episode] {
        let episodeLanguage = AppSettings.useOriginalLanguage ? show.originalLanguage : nil
        return try await fetchTMDBSeason(seriesID: show.tmdbID, season: season, language: episodeLanguage)
            .map { EpisodeMapper.map(tmdb: $0, tvmaze: nil, showID: show.id) }
    }

    private func fetchTMDBSeason(seriesID: Int, season: Int, language: String?) async throws -> [TMDBEpisodeDTO] {
        try await tmdbService.fetchEpisodes(seriesID: seriesID, season: season, language: language)
    }

    // MARK: - Horaire "à venir"

    /// "À venir" inclut aussi les épisodes récemment diffusés (jusqu'à 7 jours
    /// en arrière) — pas seulement le futur — pour qu'un épisode sorti hier ou
    /// cette semaine reste visible même si l'utilisateur n'a pas ouvert l'app
    /// le jour même.
    private static let recentlyAiredWindow: TimeInterval = 60 * 60 * 24 * 7 // 7 jours

    func getUpcomingEpisodes(for shows: [Show]) async throws -> [Episode] {
        let earliestRelevantDate = Date.now.addingTimeInterval(-Self.recentlyAiredWindow)

        // Une série .ended n'aura plus jamais de nouvel épisode : inutile de la
        // requêter pour l'horaire "à venir".
        let relevantShows = shows.filter { $0.status != .ended }

        // 1. S'assurer, en parallèle, que chaque série a des épisodes en local.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for show in relevantShows {
                group.addTask { try await self.ensureEpisodes(for: show) }
            }
            try await group.waitForAll()
        }

        // 2. Une seule requête, filtrée et triée par date dans le store.
        let cacheKeys = relevantShows.map { cacheKey(for: $0) }
        return try await episodeStore.upcoming(cacheKeys: cacheKeys, since: earliestRelevantDate)
    }
}
