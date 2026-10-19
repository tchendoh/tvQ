import Testing
import Foundation
@testable import tvQ

@MainActor
struct RecentSeasonsTests {
    private func show(seasons: Int) -> Show {
        var dto = tmdbShow()
        dto = TMDBShowDTO(
            id: dto.id, name: dto.name, overview: dto.overview, posterPath: nil, backdropPath: nil,
            genres: [], networks: [], status: dto.status, numberOfSeasons: seasons,
            externalIDs: nil, originalLanguage: "en"
        )
        return ShowMapper.map(tmdb: dto, tvmaze: nil)
    }

    @Test(arguments: [
        (0, [1]),          // série annoncée, aucune saison encore
        (1, [1]),
        (2, [1, 2]),
        (3, [1, 2, 3]),
        (4, [2, 3, 4]),
        (36, [34, 35, 36]),
    ])
    func loadsAtMostTheThreeLatestSeasons(seasons: Int, expected: [Int]) {
        #expect(ScheduleRepository.recentSeasons(of: show(seasons: seasons)) == expected)
    }
}

@MainActor
struct RecommendationFilterTests {
    private func result(genres: [Int]?) -> TMDBSearchResultDTO {
        TMDBSearchResultDTO(id: 1, name: "x", overview: "", posterPath: nil, backdropPath: nil, genreIDs: genres)
    }

    @Test func talkShowsAndNewsAreExcluded() {
        #expect(!ShowRepository.isRecommendable(result(genres: [10767])))
        #expect(!ShowRepository.isRecommendable(result(genres: [35, 10763])))
    }

    @Test func fictionIsKept() {
        #expect(ShowRepository.isRecommendable(result(genres: [18, 80])))
    }

    @Test func missingOrEmptyGenresAreKept() {
        #expect(ShowRepository.isRecommendable(result(genres: nil)))
        #expect(ShowRepository.isRecommendable(result(genres: [])))
    }
}

/// Modifie UserDefaults.standard : en série, et valeurs d'origine restaurées.
@MainActor
@Suite(.serialized)
struct CacheLanguageKeyTests {
    private func withSettings(contentLanguage: String?, useOriginal: Bool, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = [AppSettings.Keys.contentLanguage, AppSettings.Keys.useOriginalLanguage]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        defaults.set(contentLanguage, forKey: AppSettings.Keys.contentLanguage)
        defaults.set(useOriginal, forKey: AppSettings.Keys.useOriginalLanguage)
        body()
    }

    @Test func usesContentLanguage() {
        withSettings(contentLanguage: "fr-CA", useOriginal: false) {
            #expect(AppSettings.cacheLanguageKey == "fr-CA")
        }
    }

    @Test func defaultsToEnglish() {
        withSettings(contentLanguage: nil, useOriginal: false) {
            #expect(AppSettings.cacheLanguageKey == "en-US")
        }
    }

    @Test func originalLanguageHasItsOwnKey() {
        withSettings(contentLanguage: "fr-CA", useOriginal: true) {
            #expect(AppSettings.cacheLanguageKey == "original")
        }
    }
}

@MainActor
struct SmallHelpersTests {
    /// Vecteur de test officiel de SHA-256 (FIPS 180-2).
    @Test func sha256MatchesKnownVector() {
        #expect(AppleSignInNonce.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func nonceHasRequestedLengthAndIsRandom() {
        let first = AppleSignInNonce.random(length: 32)
        #expect(first.count == 32)
        #expect(first != AppleSignInNonce.random(length: 32))
    }

    /// Domaine et code de FirestoreErrorCode.resourceExhausted, écrits en dur pour ne
    /// pas lier Firebase à la cible de tests.
    @Test func quotaErrorIsRecognized() {
        #expect(FirestoreQuota.isExceeded(NSError(domain: "FIRFirestoreErrorDomain", code: 8)))
        #expect(!FirestoreQuota.isExceeded(NSError(domain: "FIRFirestoreErrorDomain", code: 14)))
        #expect(!FirestoreQuota.isExceeded(NSError(domain: NSURLErrorDomain, code: 8)))
    }
}

/// Jeux quotidiens écartés de Home (voir AppRules.Recommendations).
@MainActor
struct GameShowRuleTests {
    private func show(type: String?, episodes: Int?) -> Show {
        var show = Show(tmdbID: 1, imdbID: nil, tvmazeID: nil, title: "", overview: "", posterURL: nil,
                        backdropURL: nil, genres: [], network: nil, status: .running, numberOfSeasons: 1,
                        originalLanguage: "en")
        show.tvmazeType = type
        show.recentSeasonEpisodeCount = episodes
        return show
    }

    @Test func tvmazeTypeDecidesWhenKnown() {
        #expect(ShowRepository.isGameShow(show(type: "Game Show", episodes: 10)))
        // Survivor Québec : téléréalité quotidienne, mais pas un jeu.
        #expect(!ShowRepository.isGameShow(show(type: "Reality", episodes: 190)))
    }

    @Test func tmdbEpisodeCountIsTheFallback() {
        #expect(ShowRepository.isGameShow(show(type: nil, episodes: 190)))
        #expect(!ShowRepository.isGameShow(show(type: nil, episodes: 67)))
        #expect(!ShowRepository.isGameShow(show(type: nil, episodes: nil)))
    }

    @Test func recentSeasonCountIgnoresSpecialsAndTakesTheFullerOfTheLastTwo() {
        let seasons = [
            TMDBSeasonSummaryDTO(seasonNumber: 0, episodeCount: 500),
            TMDBSeasonSummaryDTO(seasonNumber: 40, episodeCount: 230),
            TMDBSeasonSummaryDTO(seasonNumber: 41, episodeCount: 190),
            TMDBSeasonSummaryDTO(seasonNumber: 42, episodeCount: 20),   // saison qui commence
        ]
        #expect(ShowMapper.recentSeasonEpisodeCount(seasons) == 190)
        #expect(ShowMapper.recentSeasonEpisodeCount(nil) == nil)
    }
}

