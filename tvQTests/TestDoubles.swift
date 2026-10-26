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

    private var continuations: [AsyncThrowingStream<UserShowsService.FollowedShows, Error>.Continuation] = []

    /// Comme l'écouteur Firestore : un premier envoi (après `delay`), puis le flux
    /// reste ouvert jusqu'à l'annulation. `pushRemoteChange` simule un changement
    /// fait depuis un autre appareil.
    func followedShowsUpdates(userID: String) -> AsyncThrowingStream<UserShowsService.FollowedShows, Error> {
        loadCalls += 1
        let (stream, continuation) = AsyncThrowingStream<UserShowsService.FollowedShows, Error>.makeStream()
        continuations.append(continuation)
        let delay = delay, shouldFail = shouldFail
        let snapshot = UserShowsService.FollowedShows(followedIDs: followed, mutedIDs: muted)
        Task {
            if delay != .zero { try? await Task.sleep(for: delay) }
            if shouldFail {
                continuation.finish(throwing: FakeError())
            } else {
                continuation.yield(snapshot)
            }
        }
        return stream
    }

    func pushRemoteChange() {
        let snapshot = UserShowsService.FollowedShows(followedIDs: followed, mutedIDs: muted)
        continuations.forEach { $0.yield(snapshot) }
    }

    /// Comme `followCalls`, avec le compte visé (fusion de comptes à la connexion).
    private(set) var followTargets: [FollowTarget] = []

    struct FollowTarget: Equatable {
        let showID: String
        let userID: String
    }

    func follow(showID: String, userID: String) async throws {
        followCalls.append(showID)
        followTargets.append(FollowTarget(showID: showID, userID: userID))
        if shouldFail { throw FakeError() }
    }

    var deleteShouldFail = false
    private(set) var deleteCalls: [String] = []

    func deleteAllData(userID: String) async throws {
        if deleteShouldFail { throw FakeError() }
        deleteCalls.append(userID)
    }

    func unfollow(showID: String, userID: String) async throws {
        unfollowCalls.append(showID)
        if shouldFail { throw FakeError() }
    }

    private(set) var bulkUnfollowCalls: [Set<String>] = []

    func unfollow(showIDs: Set<String>, userID: String) async throws {
        bulkUnfollowCalls.append(showIDs)
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

// MARK: - Couleur dominante

@MainActor
final class FakeColorExtractor: ShowColorExtracting {
    var color: ShowColor? = ShowColor(red: 0.2, green: 0.4, blue: 0.6)
    var accent: ShowColor? = ShowColor(red: 1.0, green: 0.7, blue: 0.2)
    private(set) var requestedURLs: [URL] = []

    func palette(for imageURL: URL) async -> ShowPalette? {
        requestedURLs.append(imageURL)
        return color.map { ShowPalette(dominant: $0, accent: accent) }
    }
}

// MARK: - Authentification

extension AppUser {
    static func anonymous(_ id: String = "anon") -> AppUser {
        AppUser(id: id, email: "", displayName: nil, isAnonymous: true)
    }

    static func account(_ id: String) -> AppUser {
        AppUser(id: id, email: "\(id)@example.com", displayName: nil, isAnonymous: false)
    }
}

@MainActor
final class FakeAuth: AuthServicing {
    var currentUser: AppUser?
    var signInMethod: AuthService.SignInMethod = .password

    var anonymousUserID: String? {
        guard let currentUser, currentUser.isAnonymous else { return nil }
        return currentUser.id
    }

    // Résultats programmés : un succès devient l'utilisateur courant.
    var signInResult: Result<AppUser, Error> = .success(.account("alice"))
    var signUpResult: Result<AppUser, Error> = .success(.account("anon"))
    var appleResult: Result<AppUser, Error> = .success(.account("anon"))
    var anonymousSignInShouldFail = false
    var anonymousSignInDelay: Duration = .zero
    var deleteShouldFail = false
    var resetShouldFail = false

    /// Appelé au début de chaque connexion : permet de vérifier ce qui s'est
    /// passé *avant* (ex. effacement du document anonyme).
    var onAuthenticate: (() -> Void)?

    private(set) var calls: [String] = []
    private(set) var anonymousSignInCount = 0

    let authStateChanges: AsyncStream<AppUser?>
    private let stateContinuation: AsyncStream<AppUser?>.Continuation

    init(currentUser: AppUser? = nil) {
        self.currentUser = currentUser
        (authStateChanges, stateContinuation) = AsyncStream<AppUser?>.makeStream()
    }

    /// Simule un changement signalé par Firebase.
    func emit(_ user: AppUser?) {
        currentUser = user
        stateContinuation.yield(user)
    }

    func signInAnonymously() async throws {
        calls.append("signInAnonymously")
        anonymousSignInCount += 1
        if anonymousSignInDelay != .zero { try? await Task.sleep(for: anonymousSignInDelay) }
        if anonymousSignInShouldFail { throw AuthServiceError.network }
        emit(.anonymous("anon-\(anonymousSignInCount)"))
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        calls.append("signIn")
        return try complete(signInResult)
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        calls.append("signUp")
        return try complete(signUpResult)
    }

    func signInWithApple(idToken: String, rawNonce: String, displayName: String?) async throws -> AppUser {
        calls.append("signInWithApple")
        return try complete(appleResult)
    }

    private func complete(_ result: Result<AppUser, Error>) throws -> AppUser {
        onAuthenticate?()
        let user = try result.get()
        currentUser = user
        return user
    }

    func sendPasswordReset(email: String) async throws {
        calls.append("sendPasswordReset")
        if resetShouldFail { throw AuthServiceError.network }
    }

    func signOut() throws {
        calls.append("signOut")
        emit(nil)
    }

    func reauthenticate(password: String) async throws {
        calls.append("reauthenticate")
    }

    func reauthenticateWithApple(idToken: String, rawNonce: String) async throws {
        calls.append("reauthenticateWithApple")
    }

    func revokeAppleToken(authorizationCode: String) async throws {
        calls.append("revokeAppleToken")
    }

    func deleteCurrentUser() async throws {
        calls.append("deleteCurrentUser")
        if deleteShouldFail { throw FakeError() }
        emit(nil)
    }
}
