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

/// Jour de diffusion local : une date seule ne recule pas d'un jour à Montréal.
struct EpisodeLocalAirDayTests {
    private let montreal: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    private func episode(_ iso: String, precise: Bool) -> Episode {
        Episode(id: "1-s1e1", showID: "1", seasonNumber: 1, episodeNumber: 1, title: "", overview: "",
                stillImageURL: nil, airDate: ISO8601DateFormatter().date(from: iso),
                hasPreciseTime: precise, runtimeMinutes: nil)
    }

    private func day(_ date: Date?) -> DateComponents? {
        date.map { montreal.dateComponents([.year, .month, .day], from: $0) }
    }

    @Test func dateOnlyKeepsItsDay() {
        // Minuit UTC le 20 = 20 h le 19 à Montréal : doit rester le 20.
        let local = episode("2026-10-20T00:00:00Z", precise: false).localAirDay(in: montreal)
        #expect(day(local) == DateComponents(year: 2026, month: 10, day: 20))
    }

    @Test func preciseTimeIsConverted() {
        // 1 h UTC le 21 = 21 h le 20 à Montréal : le 20.
        let local = episode("2026-10-21T01:00:00Z", precise: true).localAirDay(in: montreal)
        #expect(day(local) == DateComponents(year: 2026, month: 10, day: 20))
    }
}

