import Testing
import Foundation
@testable import tvQ

/// Tests des stores SwiftData (EpisodeStore, ShowStore) sur une base en mémoire :
/// aucune écriture sur disque, chaque test repart d'une base vide.
struct LocalStoresTests {

    // MARK: - Outils

    private func makeEpisode(season: Int = 1, number: Int, showID: String = "100", airDate: Date?) -> Episode {
        Episode(
            id: "\(showID)-s\(season)e\(number)",
            showID: showID,
            seasonNumber: season,
            episodeNumber: number,
            title: "Episode \(number)",
            overview: "",
            stillImageURL: nil,
            airDate: airDate,
            hasPreciseTime: airDate != nil
        )
    }

    private func makeShow(tmdbID: Int = 100, status: ShowStatus = .running, title: String = "Une série") -> Show {
        Show(
            tmdbID: tmdbID,
            imdbID: "tt0000001",
            tvmazeID: 7,
            title: title,
            overview: "Résumé",
            posterURL: nil,
            backdropURL: nil,
            genres: ["Drame"],
            network: "HBO",
            status: status,
            numberOfSeasons: 3,
            originalLanguage: "en"
        )
    }

    private func makeEpisodeStore() -> EpisodeStore {
        EpisodeStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))
    }

    private func makeShowStore() -> ShowStore {
        ShowStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))
    }

    // MARK: - EpisodeStore

    @Test func episodesAreNilWhenNeverSynced() async throws {
        let store = makeEpisodeStore()
        #expect(try await store.entry(cacheKey: "100_en") == nil)
    }

    @Test func savedEpisodesRoundTripSortedWithSyncDate() async throws {
        let store = makeEpisodeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let episodes = [
            makeEpisode(season: 1, number: 2, airDate: nil),
            makeEpisode(season: 1, number: 1, airDate: syncedAt)
        ]

        try await store.save(episodes, cacheKey: "100_en", syncedAt: syncedAt)
        let cached = try #require(try await store.entry(cacheKey: "100_en"))

        #expect(cached.syncedAt == syncedAt)
        #expect(cached.value.map(\.episodeNumber) == [1, 2])
        #expect(cached.value.first?.hasPreciseTime == true)
    }

    @Test func savingReplacesPreviousEpisodesOfTheSameKey() async throws {
        let store = makeEpisodeStore()
        try await store.save([makeEpisode(number: 1, airDate: nil), makeEpisode(number: 2, airDate: nil)], cacheKey: "100_en")
        try await store.save([makeEpisode(number: 9, airDate: nil)], cacheKey: "100_en")

        let cached = try #require(try await store.entry(cacheKey: "100_en"))
        #expect(cached.value.map(\.episodeNumber) == [9])
    }

    @Test func sameEpisodeInTwoLanguagesDoesNotCollide() async throws {
        let store = makeEpisodeStore()
        try await store.save([makeEpisode(number: 1, airDate: nil)], cacheKey: "100_en")
        try await store.save([makeEpisode(number: 1, airDate: nil), makeEpisode(number: 2, airDate: nil)], cacheKey: "100_fr")

        #expect(try await store.entry(cacheKey: "100_en")?.value.count == 1)
        #expect(try await store.entry(cacheKey: "100_fr")?.value.count == 2)
    }

    @Test func upcomingFiltersByDateAndKeysAndSortsByDate() async throws {
        let store = makeEpisodeStore()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 86_400

        try await store.save([
            makeEpisode(number: 1, airDate: now - 30 * day),   // trop ancien
            makeEpisode(number: 2, airDate: now + 5 * day),
            makeEpisode(number: 3, airDate: nil),               // non daté
            makeEpisode(number: 4, airDate: now - 2 * day)
        ], cacheKey: "100_en")
        try await store.save([
            makeEpisode(number: 1, showID: "200", airDate: now + day)
        ], cacheKey: "200_en")
        try await store.save([
            makeEpisode(number: 1, showID: "300", airDate: now + day)   // série non demandée
        ], cacheKey: "300_en")

        let upcoming = try await store.upcoming(cacheKeys: ["100_en", "200_en"], since: now - 7 * day)

        #expect(upcoming.map(\.id) == ["100-s1e4", "200-s1e1", "100-s1e2"])
    }

    @Test func clearRemovesEverything() async throws {
        let store = makeEpisodeStore()
        try await store.save([makeEpisode(number: 1, airDate: Date())], cacheKey: "100_en")
        try await store.clear()

        #expect(try await store.entry(cacheKey: "100_en") == nil)
    }

    // MARK: - ShowStore

    @Test func showIsNilWhenNeverSynced() async throws {
        let store = makeShowStore()
        #expect(try await store.entry(cacheKey: "100_en") == nil)
    }

    @Test func savedShowRoundTrips() async throws {
        let store = makeShowStore()
        let syncedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let show = makeShow()

        try await store.save(show, cacheKey: "100_en", syncedAt: syncedAt)
        let cached = try #require(try await store.entry(cacheKey: "100_en"))

        #expect(cached.value == show)
        #expect(cached.syncedAt == syncedAt)
    }

    @Test func savingAShowTwiceUpdatesTheSameEntry() async throws {
        let store = makeShowStore()
        try await store.save(makeShow(title: "Avant"), cacheKey: "100_en")
        try await store.save(makeShow(status: .ended, title: "Après"), cacheKey: "100_en")

        let cached = try #require(try await store.entry(cacheKey: "100_en"))
        #expect(cached.value.title == "Après")
        #expect(cached.value.status == .ended)
    }

    // MARK: - WatchAvailabilityStore

    @Test func savedWatchAvailabilityRoundTripsPerRegion() async throws {
        let store = WatchAvailabilityStore(modelContainer: LocalDatabase.makeContainer(inMemory: true))
        let canada = WatchAvailability(
            regionDisplayName: "Canada",
            providerNames: ["Netflix"],
            justWatchURL: URL(string: "https://www.justwatch.com")!
        )

        try await store.save(canada, cacheKey: "100_CA")

        #expect(try await store.entry(cacheKey: "100_CA")?.value == canada)
        #expect(try await store.entry(cacheKey: "100_FR") == nil)
    }
}
