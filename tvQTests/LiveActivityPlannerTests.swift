import Testing
import Foundation
@testable import tvQ

/// Règles de LiveActivityPlanner, vérifiées à l'heure de Montréal.
struct LiveActivityPlannerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar
    }()

    /// 2026-10-20 12:00 à Montréal.
    private var now: Date { date("2026-10-20T12:00:00-04:00") }

    private var planner: LiveActivityPlanner {
        LiveActivityPlanner(morningMinutes: 9 * 60, calendar: calendar)
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func show(_ id: Int = 1) -> Show {
        Show(tmdbID: id, imdbID: nil, tvmazeID: nil, title: "Série \(id)", overview: "", posterURL: nil,
             backdropURL: URL(string: "https://image.tmdb.org/t/p/w500/b.jpg"), genres: [], network: "HBO",
             status: .running, numberOfSeasons: 2, originalLanguage: "en")
    }

    private func item(_ number: Int = 1, showID: Int = 1, air: Date?, precise: Bool = true,
                      runtime: Int? = 60) -> NotificationPlanner.Item {
        let episode = Episode(id: "\(showID)-s2e\(number)", showID: "\(showID)", seasonNumber: 2,
                              episodeNumber: number, title: "Titre \(number)", overview: "",
                              stillImageURL: nil, airDate: air, hasPreciseTime: precise,
                              runtimeMinutes: runtime)
        return .init(episode: episode, show: show(showID))
    }

    @Test func eveningEpisodeStartsFifteenMinutesBeforeAndEndsWithRuntime() throws {
        let air = date("2026-10-20T21:00:00-04:00")
        let plan = planner.plan(items: [item(air: air, runtime: 45)], mutedShowIDs: [], now: now)

        let activity = try #require(plan.first)
        #expect(activity.startDate == air - 15 * 60)
        #expect(activity.airDate == air)
        #expect(activity.endDate == air + 45 * 60)
        #expect(activity.episodeCode == "S02E01")
        #expect(activity.network == "HBO")
    }

    @Test func showColorIsPassedThrough() throws {
        var colored = item(air: date("2026-10-20T21:00:00-04:00"))
        var coloredShow = colored.show
        coloredShow.dominantColor = ShowColor(red: 0.1, green: 0.2, blue: 0.3)
        colored = .init(episode: colored.episode, show: coloredShow)
        let plan = planner.plan(items: [colored], mutedShowIDs: [], now: now)
        #expect(try #require(plan.first).color == ShowColor(red: 0.1, green: 0.2, blue: 0.3))
    }

    @Test func dateOnlyEpisodesAreLeftToNotifications() {
        let plan = planner.plan(
            items: [item(air: date("2026-10-20T21:00:00-04:00"), precise: false)], mutedShowIDs: [], now: now)
        #expect(plan.isEmpty)
    }

    /// Une sortie de nuit sur une plateforme n'a pas de soirée de diffusion à suivre.
    @Test func overnightReleasesAreSkipped() {
        let plan = planner.plan(items: [
            item(1, air: date("2026-10-21T03:00:00-04:00")),
            item(2, air: date("2026-10-20T23:30:00-04:00")),
        ], mutedShowIDs: [], now: now)
        #expect(plan.isEmpty)
    }

    @Test func onlyTheComingDayIsPlanned() {
        let plan = planner.plan(items: [
            item(1, air: date("2026-10-21T11:00:00-04:00")),   // début - 15 min = dans 22 h 45
            item(2, air: date("2026-10-21T20:00:00-04:00")),   // au-delà de 24 h
        ], mutedShowIDs: [], now: now)
        #expect(plan.map(\.episodeID) == ["1-s2e1"])
    }

    /// App ouverte pendant l'épisode : l'activité est encore planifiée (démarrage immédiat).
    @Test func episodeInProgressIsKeptUntilItEnds() {
        let air = date("2026-10-20T11:30:00-04:00")
        let inProgress = planner.plan(items: [item(air: air, runtime: 60)], mutedShowIDs: [], now: now)
        #expect(inProgress.count == 1)

        let afterEnd = planner.plan(items: [item(air: air, runtime: 60)], mutedShowIDs: [], now: air + 61 * 60)
        #expect(afterEnd.isEmpty)
    }

    @Test func mutedShowsAreSkipped() {
        let plan = planner.plan(
            items: [item(air: date("2026-10-20T21:00:00-04:00"))], mutedShowIDs: ["1"], now: now)
        #expect(plan.isEmpty)
    }

    /// Saison complète à 20 h : une seule activité, qui couvre tous les épisodes.
    @Test func fullSeasonAtOnceIsOneActivity() throws {
        let air = date("2026-10-20T20:00:00-04:00")
        let plan = planner.plan(items: [item(3, air: air), item(1, air: air), item(2, air: air)],
                                mutedShowIDs: [], now: now)
        let activity = try #require(plan.first)
        #expect(plan.count == 1)
        #expect(activity.episodeID == "1-s2e1")
        #expect(activity.coveredEpisodeIDs == ["1-s2e1", "1-s2e2", "1-s2e3"])
    }

    @Test func neverMoreThanTheLimitAndSortedByAirTime() {
        let items = (0..<6).map { index in
            item(1, showID: index + 1, air: date("2026-10-20T19:00:00-04:00") + TimeInterval((5 - index) * 1800))
        }
        let plan = planner.plan(items: items, mutedShowIDs: [], now: now)
        #expect(plan.count == LiveActivityPlanner.maxCount)
        #expect(plan.map(\.airDate) == plan.map(\.airDate).sorted())
    }

    @Test func missingRuntimeFallsBackToShowsTypicalRuntime() throws {
        let air = date("2026-10-20T21:00:00-04:00")
        let plan = planner.plan(items: [
            item(1, air: air, runtime: nil),
            item(2, air: date("2026-10-27T21:00:00-04:00"), runtime: 30),
        ], mutedShowIDs: [], now: now)
        let activity = try #require(plan.first)
        #expect(activity.endDate == air + 30 * 60)
    }

    // MARK: - Avec les notifications

    @Test func notificationIsReplacedByTheLiveActivity() {
        let air = date("2026-10-20T21:00:00-04:00")
        let items = [item(air: air)]
        let activities = planner.plan(items: items, mutedShowIDs: [], now: now)
        let notifications = NotificationPlanner(timing: .atAirTime, morningMinutes: 9 * 60, calendar: calendar)
            .plan(items: items, mutedShowIDs: [], now: now,
                  liveActivityEpisodeIDs: Set(activities.flatMap(\.coveredEpisodeIDs)))
        #expect(activities.count == 1)
        #expect(notifications.isEmpty)
    }

    /// « 10 min après la fin » dit autre chose que l'activité : la notification reste.
    @Test func afterEndNotificationIsKept() {
        let air = date("2026-10-20T21:00:00-04:00")
        let items = [item(air: air)]
        let notifications = NotificationPlanner(timing: .tenMinutesAfterEnd, morningMinutes: 9 * 60, calendar: calendar)
            .plan(items: items, mutedShowIDs: [], now: now, liveActivityEpisodeIDs: ["1-s2e1"])
        #expect(notifications.count == 1)
    }
}

/// Sigle de la série dans la Dynamic Island réduite.
@MainActor
struct ShowInitialsTests {
    @Test(arguments: [
        ("Moon Knight", "MK"),
        ("Star Wars: Maul - Shadow Lord", "SW"),
        ("The Last of Us", "LOU"),
        ("Severance", "SEV"),
        ("Game of Thrones", "GOT"),
        ("L'Échappée", "ÉCH"),
        ("Les Invincibles", "INV"),
        ("It", "IT"),
        ("24", "24"),
        ("The", "THE"),
        ("", ""),
    ])
    func initials(title: String, expected: String) {
        #expect(EpisodeActivityAttributes.initials(of: title) == expected)
    }
}

struct DominantColorTests {
    private typealias RGB = ShowColor

    @Test func mostCommonHueWins() throws {
        let red = RGB(red: 0.8, green: 0.1, blue: 0.1)
        let blue = RGB(red: 0.1, green: 0.2, blue: 0.8)
        let color = try #require(DominantColor.dominant(in: Array(repeating: red, count: 70) + Array(repeating: blue, count: 30)))
        #expect(color.red > color.blue)
    }

    /// Les noirs, blancs et gris ne doivent pas l'emporter sur la couleur de la série.
    @Test func neutralPixelsAreIgnored() throws {
        let black = RGB(red: 0.02, green: 0.02, blue: 0.02)
        let gray = RGB(red: 0.5, green: 0.5, blue: 0.5)
        let green = RGB(red: 0.1, green: 0.7, blue: 0.2)
        let pixels = Array(repeating: black, count: 50) + Array(repeating: gray, count: 30) + Array(repeating: green, count: 20)
        let color = try #require(DominantColor.dominant(in: pixels))
        #expect(color.green > color.red && color.green > color.blue)
    }

    @Test func secondDistinctHueBecomesTheAccent() throws {
        let navy = RGB(red: 0.1, green: 0.15, blue: 0.5)
        let orange = RGB(red: 0.9, green: 0.5, blue: 0.1)
        let palette = try #require(DominantColor.palette(in: Array(repeating: navy, count: 70) + Array(repeating: orange, count: 30)))
        #expect(palette.dominant.blue > palette.dominant.red)
        let accent = try #require(palette.accent)
        #expect(accent.red > accent.blue)
        let background = DominantColor.readableForWhiteText(palette.dominant)
        #expect(DominantColor.contrast(accent, background) >= DominantColor.minAccentContrast)
    }

    /// Deux nuances d'une même teinte : pas d'accent (il ressemblerait au fond).
    @Test func similarHuesGiveNoAccent() throws {
        let blue = RGB(red: 0.1, green: 0.2, blue: 0.8)
        let skyBlue = RGB(red: 0.2, green: 0.4, blue: 0.9)
        let palette = try #require(DominantColor.palette(in: Array(repeating: blue, count: 60) + Array(repeating: skyBlue, count: 40)))
        #expect(palette.accent == nil)
    }

    /// Une touche de couleur sous 5 % des pixels ne suffit pas.
    @Test func rareHueIsNotAnAccent() throws {
        let green = RGB(red: 0.1, green: 0.7, blue: 0.2)
        let red = RGB(red: 0.8, green: 0.1, blue: 0.1)
        let palette = try #require(DominantColor.palette(in: Array(repeating: green, count: 97) + Array(repeating: red, count: 3)))
        #expect(palette.accent == nil)
    }

    @Test func grayscaleImageHasNoAccent() throws {
        let pixels = [RGB(red: 0.2, green: 0.2, blue: 0.2), RGB(red: 0.6, green: 0.6, blue: 0.6)]
        #expect(try #require(DominantColor.palette(in: pixels)).accent == nil)
    }

    @Test func grayscaleImageFallsBackToAverage() throws {
        let pixels = [RGB(red: 0.2, green: 0.2, blue: 0.2), RGB(red: 0.6, green: 0.6, blue: 0.6)]
        let color = try #require(DominantColor.dominant(in: pixels))
        #expect(abs(color.red - 0.4) < 0.001)
    }

    @Test func brightColorsAreDarkenedForWhiteText() {
        let yellow = RGB(red: 1, green: 0.85, blue: 0.1)
        let readable = DominantColor.readableForWhiteText(yellow)
        #expect(DominantColor.luminance(of: readable) <= DominantColor.maxLuminanceForWhiteText)
    }

    @Test func darkColorsAreLeftAlone() {
        let navy = RGB(red: 0.05, green: 0.1, blue: 0.3)
        #expect(DominantColor.readableForWhiteText(navy) == navy)
    }

    @Test func hueOfPrimaryColors() {
        #expect(DominantColor.hue(of: RGB(red: 1, green: 0, blue: 0)) == 0)
        #expect(abs(DominantColor.hue(of: RGB(red: 0, green: 1, blue: 0)) - 1.0 / 3) < 0.001)
        #expect(abs(DominantColor.hue(of: RGB(red: 0, green: 0, blue: 1)) - 2.0 / 3) < 0.001)
    }
}
