import Testing
import Foundation
@testable import tvQ

@MainActor
struct FollowedShowsStoreTests {
    private let service = FakeUserShows()
    private let offers = OfferCounter()

    @MainActor
    final class OfferCounter {
        var count = 0
    }

    /// Repositories branchés sur des doublures : le préchargement après un suivi ne
    /// touche ni le réseau ni Firestore.
    private func makeStore() -> FollowedShowsStore {
        let tmdb = FakeTMDB()
        let tvmaze = FakeTVmaze()
        return FollowedShowsStore(
            userShowsService: service,
            showRepository: ShowRepository(
                tmdbService: tmdb,
                tvmazeService: tvmaze,
                showStore: ShowStore(modelContainer: LocalDatabase.makeContainer(inMemory: true)),
                watchAvailabilityStore: WatchAvailabilityStore(modelContainer: LocalDatabase.makeContainer(inMemory: true)),
                sharedCache: FakeSharedShowCache(),
                colorExtractor: FakeColorExtractor()
            ),
            scheduleRepository: ScheduleRepository(
                tmdbService: tmdb,
                tvmazeService: tvmaze,
                episodeStore: EpisodeStore(modelContainer: LocalDatabase.makeContainer(inMemory: true)),
                sharedCache: FakeSharedEpisodeCache()
            ),
            offerNotifications: { [offers] in offers.count += 1 }
        )
    }

    private func loaded(_ store: FollowedShowsStore) async -> Bool {
        await eventually { service.loadCalls > 0 && !store.isLoading }
    }

    @Test func loadFillsFollowedAndMutedShows() async {
        service.followed = ["1", "2"]
        service.muted = ["2"]
        let store = makeStore()

        store.load(userID: "A")

        #expect(await loaded(store))
        #expect(store.followedShowIDs == ["1", "2"])
        #expect(store.areNotificationsMuted("2"))
        #expect(!store.areNotificationsMuted("1"))
    }

    /// Déconnexion pendant le chargement : les séries de l'ancien compte ne doivent
    /// pas réapparaître dans le store.
    @Test func signOutDuringLoadLeavesStoreEmpty() async {
        service.followed = ["1"]
        service.delay = .milliseconds(50)
        let store = makeStore()

        store.load(userID: "A")
        #expect(await eventually { service.loadCalls == 1 })
        store.clear()

        #expect(await eventually { !store.isLoading })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(store.followedShowIDs.isEmpty)
    }

    @Test func loadFailureShowsAnError() async {
        service.shouldFail = true
        let store = makeStore()

        store.load(userID: "A")

        #expect(await loaded(store))
        #expect(store.errorMessage != nil)
    }

    @Test func followIsOptimisticAndSaved() async {
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))

        store.toggle(showID: "42")

        #expect(store.isFollowing("42"))   // immédiatement
        #expect(await eventually { service.followCalls == ["42"] })
        #expect(store.errorMessage == nil)
    }

    @Test func followingIsLimitedButUnfollowingIsNot() async {
        service.followed = (1...FollowedShowsStore.maxFollowedShows).map(String.init)
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))

        store.toggle(showID: "9999")
        #expect(!store.isFollowing("9999"))
        #expect(store.errorMessage != nil)
        #expect(service.followCalls.isEmpty)

        store.dismissError()
        store.toggle(showID: "1")
        #expect(!store.isFollowing("1"))
        #expect(store.errorMessage == nil)
    }

    @Test func failedFollowIsRolledBack() async {
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))
        service.shouldFail = true

        store.toggle(showID: "42")

        #expect(await eventually { !store.isFollowing("42") })
        #expect(store.errorMessage != nil)
    }

    @Test func failedUnfollowIsRolledBack() async {
        service.followed = ["42"]
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))
        service.shouldFail = true

        store.toggle(showID: "42")

        #expect(!store.isFollowing("42"))   // optimiste
        #expect(await eventually { store.isFollowing("42") })
        #expect(service.unfollowCalls == ["42"])
    }

    @Test func failedMuteIsRolledBack() async {
        service.followed = ["42"]
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))
        service.shouldFail = true

        store.toggleNotifications(showID: "42")

        #expect(store.areNotificationsMuted("42"))   // optimiste
        #expect(await eventually { !store.areNotificationsMuted("42") })
        #expect(service.muteCalls.first?.muted == true)
    }

    @Test func nothingHappensWithoutAUser() async throws {
        let store = makeStore()

        store.toggle(showID: "42")
        store.toggleNotifications(showID: "42")
        try await Task.sleep(for: .milliseconds(50))

        #expect(!store.isFollowing("42"))
        #expect(service.followCalls.isEmpty && service.muteCalls.isEmpty)
    }

    // MARK: - Proposition des notifications

    @Test func successfulFollowOffersNotifications() async {
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))

        store.toggle(showID: "42")

        #expect(await eventually { offers.count == 1 })
    }

    @Test func unfollowAndFailedFollowDoNotOfferNotifications() async throws {
        service.followed = ["1"]
        let store = makeStore()
        store.load(userID: "A")
        #expect(await loaded(store))

        store.toggle(showID: "1")   // ne plus suivre
        #expect(await eventually { service.unfollowCalls == ["1"] })
        service.shouldFail = true
        store.toggle(showID: "42")  // suivi refusé par Firestore
        #expect(await eventually { !store.isFollowing("42") })
        try await Task.sleep(for: .milliseconds(50))

        #expect(offers.count == 0)
    }
}
