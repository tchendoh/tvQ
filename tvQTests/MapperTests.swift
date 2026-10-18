import Testing
import Foundation
@testable import tvQ

// Fabriques de DTO : seuls les champs utiles à chaque test sont paramétrés.

@MainActor
func tmdbEpisode(
    season: Int = 1,
    number: Int = 1,
    airDate: String? = "2026-10-20",
    stillPath: String? = "/still.jpg",
    runtime: Int? = 45
) -> TMDBEpisodeDTO {
    TMDBEpisodeDTO(
        id: season * 100 + number,
        name: "Épisode \(number)",
        overview: "Résumé",
        seasonNumber: season,
        episodeNumber: number,
        airDate: airDate,
        stillPath: stillPath,
        runtime: runtime
    )
}

@MainActor
func tvmazeEpisode(
    season: Int = 1,
    number: Int? = 1,
    airstamp: String? = "2026-10-20T21:00:00-04:00",
    runtime: Int? = 60
) -> TVmazeEpisodeDTO {
    TVmazeEpisodeDTO(
        id: 1,
        name: "Episode",
        season: season,
        number: number,
        airdate: "2026-10-20",
        airtime: "21:00",
        airstamp: airstamp,
        runtime: runtime
    )
}

@MainActor
func tmdbShow(status: String = "Returning Series", networks: [String] = ["HBO"]) -> TMDBShowDTO {
    TMDBShowDTO(
        id: 1399,
        name: "Série",
        overview: "Résumé",
        posterPath: "/poster.jpg",
        backdropPath: nil,
        genres: [TMDBGenreDTO(id: 18, name: "Drame")],
        networks: networks.enumerated().map { TMDBNetworkDTO(id: $0.offset, name: $0.element) },
        status: status,
        numberOfSeasons: 8,
        externalIDs: TMDBExternalIDsDTO(imdbID: "tt0944947", tvdbID: 121361),
        originalLanguage: "en"
    )
}

// MARK: - EpisodeMapper

/// C'est ici que se décide la date affichée et notifiée : une erreur passerait inaperçue.
@MainActor
struct EpisodeMapperTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func tvmazeTimestampWinsOverTMDBDate() {
        let episode = EpisodeMapper.map(
            tmdb: tmdbEpisode(airDate: "2026-10-20"),
            tvmaze: tvmazeEpisode(airstamp: "2026-10-20T21:00:00-04:00"),
            showID: "1399"
        )
        #expect(episode.airDate == ISO8601DateFormatter().date(from: "2026-10-21T01:00:00Z"))
        #expect(episode.hasPreciseTime)
    }

    @Test func tmdbDateOnlyIsUTCMidnightOfTheSameDay() throws {
        let episode = EpisodeMapper.map(tmdb: tmdbEpisode(airDate: "2026-10-20"), tvmaze: nil, showID: "1399")
        let airDate = try #require(episode.airDate)
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute], from: airDate)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 20)
        #expect(parts.hour == 0 && parts.minute == 0)
        #expect(!episode.hasPreciseTime)
    }

    @Test func tvmazeWithoutAirstampFallsBackToTMDBDate() {
        let episode = EpisodeMapper.map(
            tmdb: tmdbEpisode(airDate: "2026-10-20"),
            tvmaze: tvmazeEpisode(airstamp: nil),
            showID: "1399"
        )
        #expect(episode.airDate != nil)
        #expect(!episode.hasPreciseTime)
    }

    @Test func unparsableDatesGiveNoDate() {
        let episode = EpisodeMapper.map(
            tmdb: tmdbEpisode(airDate: "pas une date"),
            tvmaze: tvmazeEpisode(airstamp: "n'importe quoi"),
            showID: "1399"
        )
        #expect(episode.airDate == nil)
        #expect(!episode.hasPreciseTime)
    }

    @Test func undatedEpisodeHasNoDate() {
        let episode = EpisodeMapper.map(tmdb: tmdbEpisode(airDate: nil), tvmaze: nil, showID: "1399")
        #expect(episode.airDate == nil)
    }

    @Test func runtimePrefersTVmazeThenTMDB() {
        let both = EpisodeMapper.map(tmdb: tmdbEpisode(runtime: 45), tvmaze: tvmazeEpisode(runtime: 60), showID: "1")
        #expect(both.runtimeMinutes == 60)
        let tvmazeUnknown = EpisodeMapper.map(tmdb: tmdbEpisode(runtime: 45), tvmaze: tvmazeEpisode(runtime: nil), showID: "1")
        #expect(tvmazeUnknown.runtimeMinutes == 45)
        let none = EpisodeMapper.map(tmdb: tmdbEpisode(runtime: nil), tvmaze: nil, showID: "1")
        #expect(none.runtimeMinutes == nil)
    }

    /// Les notifications et le cache s'appuient sur cet identifiant : il ne doit pas changer.
    @Test func identifierFormatIsStable() {
        let episode = EpisodeMapper.map(tmdb: tmdbEpisode(season: 3, number: 12), tvmaze: nil, showID: "1399")
        #expect(episode.id == "1399-s3e12")
        #expect(episode.showID == "1399")
    }

    @Test func stillImageUsesTMDBImageBase() {
        let withStill = EpisodeMapper.map(tmdb: tmdbEpisode(stillPath: "/abc.jpg"), tvmaze: nil, showID: "1")
        #expect(withStill.stillImageURL?.absoluteString == "https://image.tmdb.org/t/p/w500/abc.jpg")
        let withoutStill = EpisodeMapper.map(tmdb: tmdbEpisode(stillPath: nil), tvmaze: nil, showID: "1")
        #expect(withoutStill.stillImageURL == nil)
    }
}

// MARK: - ShowMapper

/// `.ended` coupe le rafraîchissement du cache pour toujours : une série en cours mal
/// classée ne montrerait plus jamais ses nouveaux épisodes.
@MainActor
struct ShowMapperTests {
    private func status(tmdb: String, tvmaze: String?) -> ShowStatus {
        ShowMapper.map(
            tmdb: tmdbShow(status: tmdb),
            tvmaze: tvmaze.map { TVmazeShowDTO(id: 82, name: "Série", status: $0) }
        ).status
    }

    @Test(arguments: [
        ("Returning Series", ShowStatus.running),
        ("In Production", .running),
        ("Ended", .ended),
        ("Canceled", .ended),
        ("Planned", .upcoming),
        ("Pilot", .unknown),
    ])
    func tmdbStatuses(raw: String, expected: ShowStatus) {
        #expect(status(tmdb: raw, tvmaze: nil) == expected)
    }

    @Test(arguments: [
        ("Running", ShowStatus.running),
        ("Ended", .ended),
        ("Cancelled", .ended),
        ("To Be Determined", .upcoming),
        ("In Development", .unknown),
    ])
    func tvmazeStatuses(raw: String, expected: ShowStatus) {
        #expect(status(tmdb: "Pilot", tvmaze: raw) == expected)
    }

    @Test func tvmazeStatusWinsOverTMDB() {
        // TMDB pas encore à jour sur une annulation.
        #expect(status(tmdb: "Returning Series", tvmaze: "Ended") == .ended)
        // TMDB pas encore à jour sur un retour.
        #expect(status(tmdb: "Ended", tvmaze: "Running") == .running)
    }

    @Test func statusIgnoresCase() {
        #expect(status(tmdb: "RETURNING SERIES", tvmaze: nil) == .running)
        #expect(status(tmdb: "x", tvmaze: "ended") == .ended)
    }

    @Test func fieldsAreCopied() {
        let show = ShowMapper.map(tmdb: tmdbShow(networks: ["HBO", "Crave"]), tvmaze: TVmazeShowDTO(id: 82, name: "x", status: "Running"))
        #expect(show.tmdbID == 1399)
        #expect(show.id == "1399")
        #expect(show.imdbID == "tt0944947")
        #expect(show.tvmazeID == 82)
        #expect(show.network == "HBO")
        #expect(show.genres == ["Drame"])
        #expect(show.posterURL?.absoluteString == "https://image.tmdb.org/t/p/w500/poster.jpg")
        #expect(show.backdropURL == nil)
        #expect(show.numberOfSeasons == 8)
    }

    @Test func noNetworkAndNoTVmaze() {
        let show = ShowMapper.map(tmdb: tmdbShow(networks: []), tvmaze: nil)
        #expect(show.network == nil)
        #expect(show.tvmazeID == nil)
    }
}

// MARK: - WatchAvailabilityMapper

@MainActor
struct WatchAvailabilityMapperTests {
    private func providers(_ names: String...) -> [TMDBWatchProviderDTO] {
        names.enumerated().map { TMDBWatchProviderDTO(providerID: $0.offset, providerName: $0.element) }
    }

    private func dto(
        link: String? = "https://www.themoviedb.org/tv/1399/watch?locale=CA",
        flatrate: [TMDBWatchProviderDTO]? = nil,
        buy: [TMDBWatchProviderDTO]? = nil,
        rent: [TMDBWatchProviderDTO]? = nil,
        region: String = "CA"
    ) -> TMDBWatchProvidersDTO {
        TMDBWatchProvidersDTO(results: [
            region: TMDBWatchProvidersRegionDTO(link: link, flatrate: flatrate, buy: buy, rent: rent)
        ])
    }

    @Test func subscriptionComesFirstThenBuyThenRent() {
        let result = WatchAvailabilityMapper.map(
            dto: dto(flatrate: providers("Crave"), buy: providers("Apple TV"), rent: providers("Google Play Movies")),
            region: "CA"
        )
        #expect(result.providerNames == ["Crave", "Apple TV", "Google Play Movies"])
    }

    @Test func sameServiceInBuyAndRentAppearsOnce() {
        let result = WatchAvailabilityMapper.map(dto: dto(buy: providers("Apple TV"), rent: providers("Apple TV")), region: "CA")
        #expect(result.providerNames == ["Apple TV"])
    }

    @Test func aliasesAreMergedBeforeDeduplication() {
        let result = WatchAvailabilityMapper.map(
            dto: dto(flatrate: providers("Netflix", "Netflix Standard with Ads", "netflix with ads", "Disney Plus", "HBO Max")),
            region: "CA"
        )
        #expect(result.providerNames == ["Netflix", "Disney+", "Max"])
    }

    /// Décision volontaire : même marque, catalogues différents.
    @Test func sameBrandDifferentCatalogStaysSeparate() {
        let result = WatchAvailabilityMapper.map(
            dto: dto(flatrate: providers("Apple TV+", "Amazon Prime Video"), buy: providers("Apple TV", "Amazon Video")),
            region: "CA"
        )
        #expect(result.providerNames == ["Apple TV+", "Amazon Prime Video", "Apple TV", "Amazon Video"])
    }

    @Test func usesTMDBLinkForTheRegion() {
        let result = WatchAvailabilityMapper.map(dto: dto(flatrate: providers("Crave")), region: "CA")
        #expect(result.justWatchURL.absoluteString == "https://www.themoviedb.org/tv/1399/watch?locale=CA")
        #expect(result.regionDisplayName == "Canada")
    }

    @Test func missingRegionIsEmptyWithJustWatchFallback() {
        let result = WatchAvailabilityMapper.map(dto: dto(flatrate: providers("Netflix"), region: "US"), region: "CA")
        #expect(result.isEmpty)
        #expect(result.justWatchURL.absoluteString == "https://www.justwatch.com")
    }

    @Test func unknownRegionCodeIsShownAsIs() {
        let result = WatchAvailabilityMapper.map(dto: dto(region: "DE"), region: "DE")
        #expect(result.regionDisplayName == "DE")
    }
}
