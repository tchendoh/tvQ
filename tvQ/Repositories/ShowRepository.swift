import Foundation

/// Repository des séries : orchestre TMDBService et TVmazeService,
/// puis délègue à ShowMapper la construction du modèle `Show` final.
/// C'est le seul endroit (avec ScheduleRepository) qui connaît l'existence
/// des deux sources externes — le reste de l'app passe par ce repository.
///
/// Lecture en cascade : copie locale (ShowStore, SwiftData), puis copie partagée
/// (Firestore), puis TMDB/TVmaze. Une copie locale périmée est retournée quand même
/// et rafraîchie en arrière-plan, pour que résoudre ~100 séries suivies (Schedule,
/// My Shows) ne bloque jamais l'écran sur le réseau.
final class ShowRepository {
    private let tmdbService: TMDBService
    private let tvmazeService: TVmazeService
    private let showStore: ShowStore
    private let watchAvailabilityStore: WatchAvailabilityStore
    private let sharedCache: FirestoreShowCacheService

    /// Résolutions distantes déjà en cours, par clé de cache : deux écrans qui demandent
    /// la même série en même temps partagent un seul appel au lieu de le doubler.
    private var inFlight: [String: Task<(show: Show, tier: CacheTier), Error>] = [:]

    init(
        tmdbService: TMDBService = TMDBService(),
        tvmazeService: TVmazeService = TVmazeService(),
        showStore: ShowStore = .shared,
        watchAvailabilityStore: WatchAvailabilityStore = .shared,
        sharedCache: FirestoreShowCacheService = FirestoreShowCacheService()
    ) {
        self.tmdbService = tmdbService
        self.tvmazeService = tvmazeService
        self.showStore = showStore
        self.watchAvailabilityStore = watchAvailabilityStore
        self.sharedCache = sharedCache
    }

    // MARK: - Recherche et découverte

    func search(query: String) async throws -> [ShowSummary] {
        let results = try await tmdbService.searchShows(query: query)
        return results.map(mapToSummary)
    }

    func trendingShows() async throws -> [ShowSummary] {
        try await tmdbService.fetchTrendingTV().map(mapToSummary)
    }

    func onTheAirShows() async throws -> [ShowSummary] {
        try await tmdbService.fetchOnTheAirTV().map(mapToSummary)
    }

    func airingTodayShows() async throws -> [ShowSummary] {
        try await tmdbService.fetchAiringTodayTV().map(mapToSummary)
    }

    private func mapToSummary(_ dto: TMDBSearchResultDTO) -> ShowSummary {
        ShowSummary(
            tmdbID: dto.id,
            title: dto.name,
            overview: dto.overview,
            posterURL: dto.posterPath.map { ShowMapper.imageBaseURL.appendingPathComponent($0) }
        )
    }

    // MARK: - Série complète

    func getShow(tmdbID: Int) async throws -> Show {
        try await getShowWithTier(tmdbID: tmdbID).show
    }

    /// Même résultat que getShow, avec en plus d'où il vient (diagnostic de l'écran Schedule).
    func getShowWithTier(tmdbID: Int) async throws -> (show: Show, tier: CacheTier) {
        // La clé inclut la langue effective : la copie Firestore est partagée entre
        // utilisateurs et le contenu (titre, résumé) est localisé.
        let cacheKey = "\(tmdbID)_\(AppSettings.cacheLanguageKey)"

        if let local = try? await showStore.entry(cacheKey: cacheKey) {
            let isEnded = local.value.status == .ended
            if !CachePolicy.local.isFresh(syncedAt: local.syncedAt, isEnded: isEnded) {
                Task { _ = try? await self.resolveRemotely(tmdbID: tmdbID, cacheKey: cacheKey) }
            }
            return (local.value, .local)
        }

        return try await resolveRemotely(tmdbID: tmdbID, cacheKey: cacheKey)
    }

    /// Copie partagée puis TMDB/TVmaze, avec écriture dans les deux copies.
    private func resolveRemotely(tmdbID: Int, cacheKey: String) async throws -> (show: Show, tier: CacheTier) {
        if let task = inFlight[cacheKey] {
            return try await task.value
        }

        let task = Task { try await self.loadFromSharedOrRemote(tmdbID: tmdbID, cacheKey: cacheKey) }
        inFlight[cacheKey] = task
        defer { inFlight[cacheKey] = nil }
        return try await task.value
    }

    private func loadFromSharedOrRemote(tmdbID: Int, cacheKey: String) async throws -> (show: Show, tier: CacheTier) {
        if let shared = try? await sharedCache.show(cacheKey: cacheKey),
           CachePolicy.shared.isFresh(syncedAt: shared.syncedAt, isEnded: shared.value.status == .ended) {
            // On garde la date d'origine : une copie déjà vieille ne redevient pas "fraîche".
            try? await showStore.save(shared.value, cacheKey: cacheKey, syncedAt: shared.syncedAt)
            return (shared.value, .shared)
        }

        let show = try await fetchShow(tmdbID: tmdbID)
        let now = Date.now

        // Écriture best-effort dans la copie partagée : un échec (hors ligne, règles
        // Firestore) ne doit pas empêcher de retourner le résultat à l'utilisateur.
        try? await sharedCache.store(cacheKey: cacheKey, show: show, syncedAt: now)
        try? await showStore.save(show, cacheKey: cacheKey, syncedAt: now)
        return (show, .remote)
    }

    /// Appel direct aux APIs externes, sans passer par aucun cache.
    private func fetchShow(tmdbID: Int) async throws -> Show {
        var tmdbShow = try await tmdbService.fetchShowDetails(id: tmdbID)

        // Si l'utilisateur préfère la langue d'origine et qu'elle diffère de la langue
        // de contenu par défaut, on refait un appel ciblé — TMDB ne garantit pas un
        // repli fiable vers la langue d'origine sur cet endpoint.
        if AppSettings.useOriginalLanguage, !AppSettings.contentLanguage.hasPrefix(tmdbShow.originalLanguage) {
            tmdbShow = try await tmdbService.fetchShowDetails(id: tmdbID, language: tmdbShow.originalLanguage)
        }

        // Pas d'erreur si l'IMDB ID est absent : la série reste utilisable,
        // elle perd juste l'horaire précis TVmaze (repli sur les dates TMDB).
        var tvmazeShow: TVmazeShowDTO?
        if let imdbID = tmdbShow.externalIDs?.imdbID {
            tvmazeShow = try await tvmazeService.lookupShow(imdbID: imdbID)
        }

        return ShowMapper.map(tmdb: tmdbShow, tvmaze: tvmazeShow)
    }

    // MARK: - Où regarder

    /// Disponibilité de visionnement dans la région choisie (AppSettings.watchProviderRegion).
    /// Best-effort : nil si rien n'est connu, sans jamais faire échouer la fiche de la série.
    /// Copie locale seulement (pas de copie partagée, la donnée dépend de la région).
    func getWatchAvailability(tmdbID: Int) async -> WatchAvailability? {
        let region = AppSettings.watchProviderRegion
        let cacheKey = "\(tmdbID)_\(region)"
        let cached = try? await watchAvailabilityStore.entry(cacheKey: cacheKey)

        if let cached, CachePolicy.watchAvailability.isFresh(syncedAt: cached.syncedAt) {
            return cached.value
        }

        guard let dto = try? await tmdbService.fetchWatchProviders(seriesID: tmdbID) else {
            // Réseau indisponible : une donnée périmée vaut mieux que rien.
            return cached?.value
        }

        let availability = WatchAvailabilityMapper.map(dto: dto, region: region)
        try? await watchAvailabilityStore.save(availability, cacheKey: cacheKey)
        return availability
    }
}
