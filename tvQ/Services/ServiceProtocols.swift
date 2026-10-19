import Foundation

// Contrats des dépendances distantes des repositories et de FollowedShowsStore.
// L'app utilise toujours les implémentations réelles (valeurs par défaut des init) ;
// les protocoles n'existent que pour pouvoir injecter des doublures dans les tests.

protocol TMDBFetching {
    func searchShows(query: String) async throws -> [TMDBSearchResultDTO]
    func fetchShowDetails(id: Int, language: String?) async throws -> TMDBShowDTO
    func fetchEpisodes(seriesID: Int, season: Int, language: String?) async throws -> [TMDBEpisodeDTO]
    func fetchTrendingTV(timeWindow: String) async throws -> [TMDBSearchResultDTO]
    func fetchOnTheAirTV() async throws -> [TMDBSearchResultDTO]
    func fetchAiringTodayTV() async throws -> [TMDBSearchResultDTO]
    func fetchWatchProviders(seriesID: Int) async throws -> TMDBWatchProvidersDTO
}

extension TMDBFetching {
    func fetchShowDetails(id: Int) async throws -> TMDBShowDTO {
        try await fetchShowDetails(id: id, language: nil)
    }

    func fetchTrendingTV() async throws -> [TMDBSearchResultDTO] {
        try await fetchTrendingTV(timeWindow: "week")
    }
}

protocol TVmazeFetching {
    func lookupShow(imdbID: String) async throws -> TVmazeShowDTO?
    func fetchEpisodes(showID: Int) async throws -> [TVmazeEpisodeDTO]
}

/// Copie partagée (Firestore) des métadonnées de série.
protocol SharedShowCaching {
    func show(cacheKey: String) async throws -> Cached<Show>?
    func store(cacheKey: String, show: Show, syncedAt: Date) async throws
}

/// Copie partagée (Firestore) des épisodes.
protocol SharedEpisodeCaching {
    func episodes(cacheKey: String) async throws -> Cached<[Episode]>?
    func store(cacheKey: String, episodes: [Episode], syncedAt: Date) async throws
}

/// Séries suivies d'un utilisateur (Firestore).
protocol UserShowsServicing {
    func followedShows(userID: String) async throws -> UserShowsService.FollowedShows
    func follow(showID: String, userID: String) async throws
    func unfollow(showID: String, userID: String) async throws
    func unfollow(showIDs: Set<String>, userID: String) async throws
    func setNotificationsMuted(_ muted: Bool, showID: String, userID: String) async throws
}

extension TMDBService: TMDBFetching {}
extension TVmazeService: TVmazeFetching {}
extension FirestoreShowCacheService: SharedShowCaching {}
extension FirestoreEpisodeCacheService: SharedEpisodeCaching {}
extension UserShowsService: UserShowsServicing {}
