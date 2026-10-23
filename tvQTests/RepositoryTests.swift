import Testing
import Foundation
@testable import tvQ

/// Lecture en cascade des repositories (local, puis partagé, puis TMDB/TVmaze), avec
/// des doublures pour le réseau et Firestore et de vrais stores SwiftData en mémoire.
/// En série : un test modifie les réglages de langue, qui entrent dans les clés de cache.
@MainActor
@Suite(.serialized)
struct RepositoryTests {
    private let tmdb = FakeTMDB()
    private let tvmaze = FakeTVmaze()
    private let sharedShows = FakeSharedShowCache()
    private let colors = FakeColorExtractor()
    private let sharedEpisodes = FakeSharedEpisodeCache()
    private let showStore = ShowStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))
    private let episodeStore = EpisodeStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))
    private let watchStore = WatchAvailabilityStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))

    private let now = Date.now
    private var stale: Date { now.addingTimeInterval(-CachePolicy.shared.maxAge - 3600) }

    private func showRepository() -> ShowRepository {
        ShowRepository(
            tmdbService: tmdb,
            tvmazeService: tvmaze,
            showStore: showStore,
            watchAvailabilityStore: watchStore,
            sharedCache: sharedShows,
            colorExtractor: colors
        )
    }

    private func scheduleRepository() -> ScheduleRepository {
        ScheduleRepository(
            tmdbService: tmdb,
            tvmazeService: tvmaze,
            episodeStore: episodeStore,
            sharedCache: sharedEpisodes
        )
    }

    private func key(_ id: Int) -> String { "\(id)_\(AppSettings.cacheLanguageKey)" }

    private func dto(id: Int = 100, status: String = "Returning Series", imdbID: String? = "tt100",
                     language: String = "en", backdropPath: String? = nil) -> TMDBShowDTO {
        TMDBShowDTO(
            id: id, name: "Série \(id)", overview: "", posterPath: nil, backdropPath: backdropPath,
            genres: [], networks: [], status: status, numberOfSeasons: 2,
            externalIDs: TMDBExternalIDsDTO(imdbID: imdbID, tvdbID: nil), originalLanguage: language
        )
    }

    // MARK: - ShowRepository

    @Test func freshLocalCopyMakesNoRemoteCall() async throws {
        let show = makeShow(tmdbID: 100)
        try await showStore.save(show, cacheKey: key(100), syncedAt: now)

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result == show)
        #expect(tmdb.showDetailsCalls.isEmpty)
    }

    @Test func staleLocalCopyIsReturnedThenRefreshed() async throws {
        let old = makeShow(tmdbID: 100, seasons: 1)
        try await showStore.save(old, cacheKey: key(100), syncedAt: stale)
        tmdb.shows[100] = dto(id: 100)

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result == old)   // tout de suite, sans attendre le réseau
        #expect(await eventually { tmdb.showDetailsCalls.count == 1 })
        #expect(await eventually {
            (try? await showStore.entry(cacheKey: key(100)))?.value.numberOfSeasons == 2
        })
    }

    /// Plus vieille qu'un jour, mais moins d'une semaine : une série terminée
    /// n'est pas encore revérifiée (voir AppRules.Cache.endedShowMaxAge).
    @Test func recentlySyncedEndedShowIsNotRefreshed() async throws {
        try await showStore.save(makeShow(tmdbID: 100, status: .ended), cacheKey: key(100), syncedAt: stale)

        _ = try await showRepository().getShow(tmdbID: 100)
        try await Task.sleep(for: .milliseconds(100))

        #expect(tmdb.showDetailsCalls.isEmpty)
    }

    @Test func freshSharedCopyIsSavedLocallyWithItsOriginalDate() async throws {
        let show = makeShow(tmdbID: 100)
        let sharedDate = now.addingTimeInterval(-3600)
        sharedShows.entries[key(100)] = Cached(value: show, syncedAt: sharedDate)

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result == show)
        #expect(tmdb.showDetailsCalls.isEmpty)
        let local = try #require(try await showStore.entry(cacheKey: key(100)))
        #expect(abs(local.syncedAt.timeIntervalSince(sharedDate)) < 1)
    }

    @Test func staleSharedCopyIsFetchedAgainAndBothCopiesUpdated() async throws {
        sharedShows.entries[key(100)] = Cached(value: makeShow(tmdbID: 100, seasons: 1), syncedAt: stale)
        tmdb.shows[100] = dto(id: 100)
        tvmaze.show = TVmazeShowDTO(id: 7, name: "x", status: "Running")

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result.numberOfSeasons == 2)
        #expect(result.tvmazeID == 7)
        #expect(sharedShows.storeCalls == 1)
        #expect(try await showStore.entry(cacheKey: key(100))?.value == result)
    }

    @Test func sharedWriteFailureDoesNotFailTheRequest() async throws {
        tmdb.shows[100] = dto(id: 100)
        sharedShows.failOnStore = true

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result.tmdbID == 100)
        #expect(try await showStore.entry(cacheKey: key(100)) != nil)
    }

    @Test func concurrentRequestsShareOneRemoteCall() async throws {
        tmdb.shows[100] = dto(id: 100)
        tmdb.delay = .milliseconds(50)
        let repository = showRepository()

        async let first = repository.getShow(tmdbID: 100)
        async let second = repository.getShow(tmdbID: 100)
        let (a, b) = try await (first, second)

        #expect(a == b)
        #expect(tmdb.showDetailsCalls.count == 1)
    }

    @Test func showWithoutIMDBIDSkipsTVmaze() async throws {
        tmdb.shows[100] = dto(id: 100, imdbID: nil)

        let result = try await showRepository().getShow(tmdbID: 100)

        #expect(result.tvmazeID == nil)
        #expect(tvmaze.lookupCalls == 0)
    }

    @Test func originalLanguageTriggersASecondTargetedCall() async throws {
        let defaults = UserDefaults.standard
        let keys = [AppSettings.Keys.contentLanguage, AppSettings.Keys.useOriginalLanguage]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        defaults.set("fr-CA", forKey: AppSettings.Keys.contentLanguage)
        defaults.set(true, forKey: AppSettings.Keys.useOriginalLanguage)
        tmdb.shows[100] = dto(id: 100, language: "ja")

        _ = try await showRepository().getShow(tmdbID: 100)

        #expect(tmdb.showDetailsCalls.map(\.language) == [nil, "ja"])
    }

    @Test func originalLanguageMatchingContentLanguageMakesOneCall() async throws {
        let defaults = UserDefaults.standard
        let keys = [AppSettings.Keys.contentLanguage, AppSettings.Keys.useOriginalLanguage]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        defaults.set("fr-CA", forKey: AppSettings.Keys.contentLanguage)
        defaults.set(true, forKey: AppSettings.Keys.useOriginalLanguage)
        tmdb.shows[100] = dto(id: 100, language: "fr")

        _ = try await showRepository().getShow(tmdbID: 100)

        #expect(tmdb.showDetailsCalls.count == 1)
    }

    // MARK: - Couleur dominante

    @Test func fetchedShowGetsItsColorAndKeepsItInBothCopies() async throws {
        tmdb.shows[100] = dto(id: 100, backdropPath: "/fond.jpg")

        let show = try await showRepository().getShow(tmdbID: 100)

        #expect(show.dominantColor == colors.color)
        #expect(show.accentColor == colors.accent)
        #expect(colors.requestedURLs.map(\.lastPathComponent) == ["fond.jpg"])
        #expect(try await showStore.entry(cacheKey: key(100))?.value.dominantColor == colors.color)
        #expect(sharedShows.entries[key(100)]?.value.dominantColor == colors.color)
    }

    @Test func showWithoutImageHasNoColorAndNoRequest() async throws {
        tmdb.shows[100] = dto(id: 100)

        let show = try await showRepository().getShow(tmdbID: 100)

        #expect(show.dominantColor == nil)
        #expect(colors.requestedURLs.isEmpty)
    }

    /// Copie encore fraîche mais sans couleur (série terminée, synchronisée il y a
    /// 3 jours : plus d'un jour, moins que endedShowMaxAge) : la couleur est ajoutée
    /// en arrière-plan, sans rajeunir la copie. Une copie périmée, elle, est
    /// rafraîchie au complet (et reçoit sa couleur à ce moment-là).
    @Test func cachedShowWithoutColorIsBackfilledKeepingItsDate() async throws {
        let oldDate = now.addingTimeInterval(-3 * 86_400)
        let old = Show(tmdbID: 100, imdbID: nil, tvmazeID: nil, title: "Ancienne", overview: "",
                       posterURL: nil, backdropURL: URL(string: "https://image.tmdb.org/t/p/w500/fond.jpg"),
                       genres: [], network: nil, status: .ended, numberOfSeasons: 1, originalLanguage: "en")
        try await showStore.save(old, cacheKey: key(100), syncedAt: oldDate)
        let repository = showRepository()

        let result = try await repository.getShow(tmdbID: 100)
        #expect(result.dominantColor == nil)   // tout de suite, sans attendre

        #expect(await eventually {
            (try? await showStore.entry(cacheKey: key(100)))?.value.dominantColor == colors.color
        })
        let local = try #require(try await showStore.entry(cacheKey: key(100)))
        #expect(abs(local.syncedAt.timeIntervalSince(oldDate)) < 1)
        #expect(tmdb.showDetailsCalls.isEmpty)

        // Une seule tentative par lancement.
        _ = try await repository.getShow(tmdbID: 100)
        try await Task.sleep(for: .milliseconds(50))
        #expect(colors.requestedURLs.count == 1)
    }

    // MARK: - Où regarder

    @Test func staleWatchAvailabilityIsKeptWhenOffline() async throws {
        let region = AppSettings.watchProviderRegion
        let old = WatchAvailability(regionDisplayName: "Canada", included: ["Crave"], free: [], buyOrRent: [], justWatchURL: URL(string: "https://www.justwatch.com")!)
        try await watchStore.save(old, cacheKey: "100_\(region)", syncedAt: .distantPast)
        tmdb.watchProviders = nil   // échec réseau

        let result = await showRepository().getWatchAvailability(tmdbID: 100)

        #expect(result == old)
        #expect(tmdb.watchProvidersCalls == 1)
    }

    // MARK: - ScheduleRepository

    @Test func onlyTheThreeLatestSeasonsAreFetched() async throws {
        let show = makeShow(tmdbID: 100, seasons: 5, tvmazeID: nil)

        _ = try await scheduleRepository().getEpisodes(for: show)

        #expect(Set(tmdb.seasonCalls) == [3, 4, 5])
    }

    @Test func seasonsArrivingOutOfOrderAreSorted() async throws {
        let show = makeShow(tmdbID: 100, seasons: 2, tvmazeID: nil)
        tmdb.seasons[1] = [tmdbEpisode(season: 1, number: 2), tmdbEpisode(season: 1, number: 1)]
        tmdb.seasons[2] = [tmdbEpisode(season: 2, number: 1)]
        tmdb.seasonDelays[1] = .milliseconds(50)   // la saison 1 arrive en dernier

        let episodes = try await scheduleRepository().getEpisodes(for: show)

        #expect(episodes.map(\.id) == ["100-s1e1", "100-s1e2", "100-s2e1"])
    }

    @Test func tvmazeTimesAreJoinedBySeasonAndNumber() async throws {
        let show = makeShow(tmdbID: 100, seasons: 1, tvmazeID: 7)
        tmdb.seasons[1] = [tmdbEpisode(season: 1, number: 1), tmdbEpisode(season: 1, number: 2)]
        tvmaze.episodes = [
            tvmazeEpisode(season: 1, number: 2, airstamp: "2026-10-20T21:00:00-04:00"),
            tvmazeEpisode(season: 1, number: nil, airstamp: "2026-10-01T21:00:00-04:00"),   // spécial
        ]

        let episodes = try await scheduleRepository().getEpisodes(for: show)

        #expect(episodes.map(\.hasPreciseTime) == [false, true])
        #expect(episodes.count == 2)   // le spécial sans numéro n'ajoute rien
    }

    @Test func showWithoutTVmazeIDSkipsTVmaze() async throws {
        _ = try await scheduleRepository().getEpisodes(for: makeShow(tmdbID: 100, tvmazeID: nil))
        #expect(tvmaze.episodesCalls == 0)
    }

    @Test func freshSharedEpisodesAreUsedWithoutTMDB() async throws {
        let show = makeShow(tmdbID: 100)
        let episode = EpisodeMapper.map(tmdb: tmdbEpisode(), tvmaze: nil, showID: show.id)
        let sharedDate = now.addingTimeInterval(-3600)
        sharedEpisodes.entries[key(100)] = Cached(value: [episode], syncedAt: sharedDate)

        let episodes = try await scheduleRepository().getEpisodes(for: show)

        #expect(episodes == [episode])
        #expect(tmdb.seasonCalls.isEmpty)
        let local = try #require(try await episodeStore.syncedAt(cacheKey: key(100)))
        #expect(abs(local.timeIntervalSince(sharedDate)) < 1)
    }

    @Test func sharedEpisodeWriteFailureDoesNotFailTheRequest() async throws {
        tmdb.seasons[1] = [tmdbEpisode()]
        sharedEpisodes.failOnStore = true

        let episodes = try await scheduleRepository().getEpisodes(for: makeShow(tmdbID: 100, tvmazeID: nil))

        #expect(episodes.count == 1)
    }

    @Test func concurrentEpisodeRequestsShareOneRemoteCall() async throws {
        let show = makeShow(tmdbID: 100, seasons: 1, tvmazeID: nil)
        tmdb.delay = .milliseconds(50)
        let repository = scheduleRepository()

        async let first = repository.getEpisodes(for: show)
        async let second = repository.getEpisodes(for: show)
        _ = try await (first, second)

        #expect(tmdb.seasonCalls == [1])
    }

    @Test func upcomingSkipsEndedShowsAndOldEpisodes() async throws {
        let running = makeShow(tmdbID: 100, tvmazeID: nil)
        let ended = makeShow(tmdbID: 200, status: .ended, tvmazeID: nil)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let soon = formatter.string(from: now.addingTimeInterval(3 * 86_400))
        let longAgo = formatter.string(from: now.addingTimeInterval(-30 * 86_400))
        tmdb.seasons[1] = [tmdbEpisode(number: 1, airDate: longAgo), tmdbEpisode(number: 2, airDate: soon)]

        let upcoming = try await scheduleRepository().getUpcomingEpisodes(for: [running, ended])

        #expect(upcoming.map(\.id) == ["100-s1e2"])
        #expect(tmdb.seasonCalls == [1])   // une seule série interrogée
    }
}
