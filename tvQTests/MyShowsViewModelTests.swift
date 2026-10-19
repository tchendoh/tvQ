import Testing
import Foundation
@testable import tvQ

/// Épisode le plus proche de chaque série (tri « récent » et affichage en liste).
struct MyShowsNearestEpisodeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func episode(_ number: Int, show: String = "1", daysFromNow: Double?) -> Episode {
        Episode(id: "\(show)-s1e\(number)", showID: show, seasonNumber: 1, episodeNumber: number,
                title: "", overview: "", stillImageURL: nil,
                airDate: daysFromNow.map { now + $0 * 86_400 }, hasPreciseTime: true, runtimeMinutes: nil)
    }

    @Test func closestToNowWinsWhetherPastOrFuture() {
        let result = MyShowsViewModel.nearest(in: [
            episode(1, daysFromNow: -5),
            episode(2, daysFromNow: -1),
            episode(3, daysFromNow: 6),
        ], now: now)
        #expect(result["1"]?.episodeNumber == 2)
    }

    @Test func eachShowKeepsItsOwnEpisode() {
        let result = MyShowsViewModel.nearest(in: [
            episode(1, show: "1", daysFromNow: 3),
            episode(1, show: "2", daysFromNow: 10),
        ], now: now)
        #expect(result["1"]?.episodeNumber == 1)
        #expect(result["2"] != nil)
    }

    @Test func episodesWithoutDateAreIgnored() {
        #expect(MyShowsViewModel.nearest(in: [episode(1, daysFromNow: nil)], now: now).isEmpty)
    }
}
