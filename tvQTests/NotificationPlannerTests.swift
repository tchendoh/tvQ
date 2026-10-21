import Testing
import Foundation
@testable import tvQ

/// Règles de NotificationPlanner, vérifiées à l'heure de Montréal.
struct NotificationPlannerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    /// 2026-10-20 12:00 à Montréal.
    private var now: Date { date("2026-10-20T12:00:00-04:00") }

    private func planner(_ timing: NotificationTiming = .atAirTime) -> NotificationPlanner {
        NotificationPlanner(timing: timing, morningMinutes: 9 * 60, calendar: calendar)
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func show(_ id: Int = 1, title: String = "Severance") -> Show {
        Show(tmdbID: id, imdbID: nil, tvmazeID: nil, title: title, overview: "", posterURL: nil,
             backdropURL: nil, genres: [], network: nil, status: .running, numberOfSeasons: 2,
             originalLanguage: "en")
    }

    private func episode(_ number: Int = 5, season: Int = 2, showID: String = "1",
                         airDate: Date?, precise: Bool, runtime: Int? = nil) -> Episode {
        Episode(id: "\(showID)-s\(season)e\(number)", showID: showID, seasonNumber: season,
                episodeNumber: number, title: "Titre", overview: "", stillImageURL: nil,
                airDate: airDate, hasPreciseTime: precise, runtimeMinutes: runtime)
    }

    private func item(_ episode: Episode, _ show: Show? = nil) -> NotificationPlanner.Item {
        .init(episode: episode, show: show ?? self.show())
    }

    @Test func preciseEveningEpisodeUsesExactTimeWithOffset() {
        let air = date("2026-10-21T21:00:00-04:00")
        let plan = planner(.tenMinutesBefore).plan(
            items: [item(episode(airDate: air, precise: true))], mutedShowIDs: [], now: now)
        #expect(plan.count == 1)
        #expect(plan[0].trigger == .exact(air - 600))
    }

    @Test func afterEndUsesEpisodeRuntime() {
        let air = date("2026-10-21T20:00:00-04:00")
        let plan = planner(.tenMinutesAfterEnd).plan(
            items: [item(episode(airDate: air, precise: true, runtime: 30))], mutedShowIDs: [], now: now)
        #expect(plan.first?.trigger == .exact(air + 40 * 60))
    }

    @Test func afterEndFallsBackToShowsTypicalRuntime() {
        let first = date("2026-10-21T20:00:00-04:00")
        let second = date("2026-10-28T20:00:00-04:00")
        let plan = planner(.tenMinutesAfterEnd).plan(
            items: [item(episode(5, airDate: first, precise: true, runtime: 45)),
                    item(episode(6, airDate: second, precise: true))],
            mutedShowIDs: [], now: now)
        #expect(plan.last?.trigger == .exact(second + 55 * 60))
    }

    @Test func streamingReleaseAtThreeAMMovesToMorning() {
        // Minuit heure du Pacifique = 3 h à Montréal.
        let air = date("2026-10-22T00:00:00-07:00")
        let plan = planner().plan(items: [item(episode(airDate: air, precise: true))], mutedShowIDs: [], now: now)
        let expected = DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 0)
        #expect(plan.first?.trigger == .floating(expected))
    }

    @Test func lateNightEpisodeMovesToNextMorning() {
        let air = date("2026-10-21T23:30:00-04:00")
        let plan = planner().plan(items: [item(episode(airDate: air, precise: true))], mutedShowIDs: [], now: now)
        let expected = DateComponents(year: 2026, month: 10, day: 22, hour: 9, minute: 0)
        #expect(plan.first?.trigger == .floating(expected))
    }

    @Test func tmdbDateOnlyKeepsItsCalendarDay() {
        // Date seule TMDB, lue comme minuit UTC = 20 h la veille à Montréal.
        let air = date("2026-10-23T00:00:00Z")
        let plan = planner().plan(items: [item(episode(airDate: air, precise: false))], mutedShowIDs: [], now: now)
        let expected = DateComponents(year: 2026, month: 10, day: 23, hour: 9, minute: 0)
        #expect(plan.first?.trigger == .floating(expected))
    }

    // Raison d'un report au matin : décide du message (pas de « nouvel épisode
    // aujourd'hui » à 9 h pour un épisode diffusé hier soir).

    @Test func onTimeEpisodeHasNoMorningReason() {
        let air = date("2026-10-21T21:00:00-04:00")
        #expect(planner().slot(for: episode(airDate: air, precise: true))?.reason == .onTime)
    }

    @Test func dateOnlyEpisodeIsAnnouncedAsToday() {
        let air = date("2026-10-23T00:00:00Z")
        #expect(planner().slot(for: episode(airDate: air, precise: false))?.reason == .dateOnly)
    }

    @Test func streamingReleaseAtThreeAMIsOutSinceLastNight() {
        let air = date("2026-10-22T00:00:00-07:00")
        #expect(planner().slot(for: episode(airDate: air, precise: true))?.reason == .releasedOvernight)
    }

    @Test func releaseAtSevenAMIsOutSinceThisMorning() {
        let air = date("2026-10-22T07:00:00-04:00")
        #expect(planner().slot(for: episode(airDate: air, precise: true))?.reason == .releasedEarlyMorning)
    }

    @Test func lateNightEpisodeAiredLastNight() {
        let air = date("2026-10-21T23:30:00-04:00")
        #expect(planner().slot(for: episode(airDate: air, precise: true))?.reason == .airedLastNight)
    }

    @Test func afterEndPastMidnightStillAiredLastNight() {
        // Commence à 23 h, finit vers minuit : notifié le matin, mais diffusé hier soir.
        let air = date("2026-10-21T23:00:00-04:00")
        let slot = planner(.tenMinutesAfterEnd).slot(for: episode(airDate: air, precise: true), runtimeMinutes: 60)
        #expect(slot?.reason == .airedLastNight)
    }

    @Test func tenMinutesBeforeAMidnightReleaseIsOutSinceLastNight() {
        // Sortie à 0 h 05 : 23 h 55 tombe dans la nuit, reporté au matin.
        let air = date("2026-10-22T00:05:00-04:00")
        #expect(planner(.tenMinutesBefore).slot(for: episode(airDate: air, precise: true))?.reason == .releasedOvernight)
    }

    @Test func mutedShowIsSkipped() {
        let air = date("2026-10-21T21:00:00-04:00")
        let plan = planner().plan(items: [item(episode(airDate: air, precise: true))], mutedShowIDs: ["1"], now: now)
        #expect(plan.isEmpty)
    }

    @Test func pastAndFarFutureEpisodesAreSkipped() {
        let past = date("2026-10-19T21:00:00-04:00")
        let far = date("2026-12-20T21:00:00-05:00")
        let plan = planner().plan(
            items: [item(episode(1, airDate: past, precise: true)), item(episode(2, airDate: far, precise: true))],
            mutedShowIDs: [], now: now)
        #expect(plan.isEmpty)
    }

    @Test func fullSeasonDropIsOneNotification() {
        let air = date("2026-10-22T00:00:00-07:00")
        let items = (1...8).map { item(episode($0, airDate: air, precise: true)) }
        let plan = planner().plan(items: items, mutedShowIDs: [], now: now)
        #expect(plan.count == 1)
    }

    @Test func identifiersAreStable() {
        let air = date("2026-10-21T21:00:00-04:00")
        let items = [item(episode(airDate: air, precise: true))]
        let first = planner().plan(items: items, mutedShowIDs: [], now: now)
        let second = planner().plan(items: items, mutedShowIDs: [], now: now + 60)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func neverMoreThanTheLimit() {
        let items = (0..<100).map { index in
            item(episode(1, showID: "\(index)", airDate: now + Double(index + 1) * 3600 * 4, precise: true),
                 show(index))
        }
        let plan = planner().plan(items: items, mutedShowIDs: [], now: now)
        #expect(plan.count == NotificationPlanner.maxCount)
        #expect(plan == plan.sorted { $0.fireDate < $1.fireDate })
    }
}
