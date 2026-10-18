import Foundation
@testable import tvQ

struct FakeError: Error {}

/// Attend qu'une condition devienne vraie (tâches lancées en arrière-plan), au plus ~2 s.
@MainActor
func eventually(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<200 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}

@MainActor
func makeShow(
    tmdbID: Int = 100,
    status: ShowStatus = .running,
    seasons: Int = 1,
    tvmazeID: Int? = 7,
    originalLanguage: String = "en"
) -> Show {
    Show(
        tmdbID: tmdbID,
        imdbID: "tt\(tmdbID)",
        tvmazeID: tvmazeID,
        title: "Série \(tmdbID)",
        overview: "",
        posterURL: nil,
        backdropURL: nil,
        genres: [],
        network: nil,
        status: status,
        numberOfSeasons: seasons,
        originalLanguage: originalLanguage
    )
}

// MARK: - TMDB

@MainActor
final class FakeTMDB: TMDBFetching {
    var shows: [Int: TMDBShowDTO] = [:]
    /// Épisodes par saison.
    var seasons: [Int: [TMDBEpisodeDTO]] = [:]
    /// Délai par saison, pour faire arriver les saisons dans le désordre.
    var seasonDelays: [Int: Duration] = [:]
    var delay: Duration = .zero
    var watchProviders: TMDBWatchProvidersDTO?

    private(set) var showDetailsCalls: [(id: Int, language: String?)] = []
    private(set) var seasonCalls: [Int] = []
    private(set) var watchProvidersCalls = 0

    func searchShows(query: String) async throws -> [TMDBSearchResultDTO] { [] }

    func fetchShowDetails(id: Int, language: String?) async throws -> TMDBShowDTO {
        showDetailsCalls.append((id, language))
        if delay != .zero { try await Task.sleep(for: delay) }
        guard let show = shows[id] else { throw FakeError() }
        return show
    }

    func fetchEpisodes(seriesID: Int, season: Int, language: String?) async throws -> [TMDBEpisodeDTO] {
        seasonCalls.append(season)
        let wait = seasonDelays[season] ?? delay
        if wait != .zero { try await Task.sleep(for: wait) }
        return seasons[season] ?? []
    }

    func fetchTrendingTV(timeWindow: String) async throws -> [TMDBSearchResultDTO] { [] }
    func fetchOnTheAirTV() async throws -> [TMDBSearchResultDTO] { [] }
    func fetchAiringTodayTV() async throws -> [TMDBSearchResultDTO] { [] }

    func fetchWatchProviders(seriesID: Int) async throws -> TMDBWatchProvidersDTO {
        watchProvidersCalls += 1
        guard let watchProviders else { throw FakeError() }
        return watchProviders
    }
}

// MARK: - TVmaze

@MainActor
final class FakeTVmaze: TVmazeFetching {
    var show: TVmazeShowDTO?
    var episodes: [TVmazeEpisodeDTO] = []
    private(set) var lookupCalls = 0
    private(set) var episodesCalls = 0

    func lookupShow(imdbID: String) async throws -> TVmazeShowDTO? {
        lookupCalls += 1
        return show
    }

    func fetchEpisodes(showID: Int) async throws -> [TVmazeEpisodeDTO] {
        episodesCalls += 1
        return episodes
    }
}

// MARK: - Copies partagées (Firestore)

@MainActor
final class FakeSharedShowCache: SharedShowCaching {
    var entries: [String: Cached<Show>] = [:]
    var failOnStore = false
    private(set) var storeCalls = 0

    func show(cacheKey: String) async throws -> Cached<Show>? { entries[cacheKey] }

    func store(cacheKey: String, show: Show, syncedAt: Date) async throws {
        storeCalls += 1
        if failOnStore { throw FakeError() }
        entries[cacheKey] = Cached(value: show, syncedAt: syncedAt)
    }
}

@MainActor
final class FakeSharedEpisodeCache: SharedEpisodeCaching {
    var entries: [String: Cached<[Episode]>] = [:]
    var failOnStore = false
    private(set) var storeCalls = 0

    func episodes(cacheKey: String) async throws -> Cached<[Episode]>? { entries[cacheKey] }

    func store(cacheKey: String, episodes: [Episode], syncedAt: Date) async throws {
        storeCalls += 1
        if failOnStore { throw FakeError() }
        entries[cacheKey] = Cached(value: episodes, syncedAt: syncedAt)
    }
}

// MARK: - Séries suivies

@MainActor
final class FakeUserShows: UserShowsServicing {
    var followed: [String] = []
    var muted: [String] = []
    var delay: Duration = .zero
    var shouldFail = false
    private(set) var loadCalls = 0
    private(set) var followCalls: [String] = []
    private(set) var unfollowCalls: [String] = []
    private(set) var muteCalls: [(muted: Bool, showID: String)] = []

    func followedShows(userID: String) async throws -> UserShowsService.FollowedShows {
        loadCalls += 1
        if delay != .zero { try await Task.sleep(for: delay) }
        if shouldFail { throw FakeError() }
        return UserShowsService.FollowedShows(followedIDs: followed, mutedIDs: muted)
    }

    func follow(showID: String, userID: String) async throws {
        followCalls.append(showID)
        if shouldFail { throw FakeError() }
    }

    func unfollow(showID: String, userID: String) async throws {
        unfollowCalls.append(showID)
        if shouldFail { throw FakeError() }
    }

    func setNotificationsMuted(_ muted: Bool, showID: String, userID: String) async throws {
        muteCalls.append((muted, showID))
        if shouldFail { throw FakeError() }
    }
}

// MARK: - Jeton TMDB

/// Appelée depuis l'actor TMDBToken : état protégé par un verrou.
final class FakeTokenSource: TMDBTokenSource, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    private var tokenAfterFetch: String?
    private var failuresLeft: Int
    private var delay: Duration
    private var _fetchCount = 0
    private var _forcedFetchCount = 0

    init(cached: String?, afterFetch: String? = nil, failures: Int = 0, delay: Duration = .zero) {
        token = cached
        tokenAfterFetch = afterFetch
        failuresLeft = failures
        self.delay = delay
    }

    var fetchCount: Int { lock.withLock { _fetchCount } }
    var forcedFetchCount: Int { lock.withLock { _forcedFetchCount } }

    /// Simule un changement de valeur publié dans la console.
    func publish(_ newValue: String) {
        lock.withLock { tokenAfterFetch = newValue }
    }

    func forceFetchAndActivate() async throws {
        let wait = lock.withLock { () -> Duration in
            _forcedFetchCount += 1
            return delay
        }
        if wait != .zero { try await Task.sleep(for: wait) }
        lock.withLock {
            if let tokenAfterFetch { token = tokenAfterFetch }
        }
    }

    func cachedToken() -> String? {
        lock.withLock { token.flatMap { $0.isEmpty ? nil : $0 } }
    }

    func fetchAndActivate() async throws {
        let wait = lock.withLock { () -> Duration in
            _fetchCount += 1
            return delay
        }
        if wait != .zero { try await Task.sleep(for: wait) }
        try lock.withLock {
            if failuresLeft > 0 {
                failuresLeft -= 1
                throw FakeError()
            }
            if let tokenAfterFetch { token = tokenAfterFetch }
        }
    }
}
