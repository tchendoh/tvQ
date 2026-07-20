import Foundation

/// Implémentation concrète de ShowRepository : orchestre TMDBClient et TVmazeClient,
/// puis délègue à ShowMapper la construction de l'entité Domain finale.
/// C'est le seul endroit (avec RemoteScheduleRepository) qui connaît l'existence
/// des deux sources externes — le reste de l'app ne voit que le protocole.
///
/// getShow(tmdbID:) suit le même cache à 3 paliers que RemoteScheduleRepository
/// (local → Firestore partagé → TMDB/TVmaze) — voir LocalShowCache et
/// FirestoreShowCacheRepository. Sans ça, résoudre ~100 séries suivies (Schedule,
/// My Shows) refaisait un aller-retour réseau complet à chaque ouverture d'écran.
final class RemoteShowRepository: ShowRepository {
    private let tmdbClient: TMDBClient
    private let tvmazeClient: TVmazeClient
    private let localCache: LocalShowCache
    private let sharedCache: FirestoreShowCacheRepository

    init(
        tmdbClient: TMDBClient = TMDBClient(),
        tvmazeClient: TVmazeClient = TVmazeClient(),
        localCache: LocalShowCache = .shared,
        sharedCache: FirestoreShowCacheRepository = FirestoreShowCacheRepository()
    ) {
        self.tmdbClient = tmdbClient
        self.tvmazeClient = tvmazeClient
        self.localCache = localCache
        self.sharedCache = sharedCache
    }

    func search(query: String) async throws -> [ShowSummary] {
        let results = try await tmdbClient.searchShows(query: query)
        return results.map(mapToSummary)
    }

    func trendingShows() async throws -> [ShowSummary] {
        try await tmdbClient.fetchTrendingTV().map(mapToSummary)
    }

    func onTheAirShows() async throws -> [ShowSummary] {
        try await tmdbClient.fetchOnTheAirTV().map(mapToSummary)
    }

    func airingTodayShows() async throws -> [ShowSummary] {
        try await tmdbClient.fetchAiringTodayTV().map(mapToSummary)
    }

    private func mapToSummary(_ dto: TMDBSearchResultDTO) -> ShowSummary {
        ShowSummary(
            tmdbID: dto.id,
            title: dto.name,
            overview: dto.overview,
            posterURL: dto.posterPath.map { ShowMapper.imageBaseURL.appendingPathComponent($0) }
        )
    }

    func getShow(tmdbID: Int) async throws -> Show {
        // Même raisonnement que RemoteScheduleRepository.getEpisodes : la clé
        // inclut la langue effective, parce que le cache Firestore est partagé
        // entre utilisateurs et le contenu (titre, résumé) est localisé.
        let cacheKey = "\(tmdbID)_\(AppSettings.cacheLanguageKey)"

        if let cached = await localCache.show(cacheKey: cacheKey) {
            return cached
        }

        if let cached = try? await sharedCache.show(cacheKey: cacheKey) {
            await localCache.store(cacheKey: cacheKey, show: cached)
            return cached
        }

        let show = try await fetchShow(tmdbID: tmdbID)

        // Écriture best-effort dans le cache partagé — un échec ici ne doit pas
        // empêcher de retourner le résultat déjà obtenu à l'utilisateur courant.
        try? await sharedCache.store(cacheKey: cacheKey, show: show)
        await localCache.store(cacheKey: cacheKey, show: show)

        return show
    }

    /// Appel direct aux APIs externes, sans passer par aucun des deux caches —
    /// utilisé uniquement par getShow(tmdbID:) une fois les deux paliers vérifiés.
    private func fetchShow(tmdbID: Int) async throws -> Show {
        var tmdbShow = try await tmdbClient.fetchShowDetails(id: tmdbID)

        // Si l'utilisateur préfère la langue d'origine et qu'elle diffère de la langue
        // de contenu par défaut, on refait un appel ciblé — TMDB ne garantit pas un
        // repli fiable vers la langue d'origine sur cet endpoint (voir discussion).
        if AppSettings.useOriginalLanguage, !AppSettings.contentLanguage.hasPrefix(tmdbShow.originalLanguage) {
            tmdbShow = try await tmdbClient.fetchShowDetails(id: tmdbID, language: tmdbShow.originalLanguage)
        }

        // Pas d'erreur si l'IMDB ID est absent : la série reste utilisable,
        // elle perd juste l'horaire précis TVmaze (repli sur les dates TMDB).
        var tvmazeShow: TVmazeShowDTO?
        if let imdbID = tmdbShow.externalIDs?.imdbID {
            tvmazeShow = try await tvmazeClient.lookupShow(imdbID: imdbID)
        }

        return ShowMapper.map(tmdb: tmdbShow, tvmaze: tvmazeShow)
    }
}
