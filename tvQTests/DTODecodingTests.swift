import Testing
import Foundation
@testable import tvQ

/// Protège contre un changement de format des API tierces : un champ devenu null ou
/// absent ferait échouer silencieusement tout un écran.
@MainActor
struct DTODecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func tmdbShowDetails() throws {
        let show = try decode(TMDBShowDTO.self, Fixtures.tmdbShowDetails)
        #expect(show.id == 1399)
        #expect(show.status == "Ended")
        #expect(show.numberOfSeasons == 8)
        #expect(show.externalIDs?.imdbID == "tt0944947")
        #expect(show.networks.first?.name == "HBO")
        #expect(show.genres.map(\.id) == [10765, 18])
        #expect(show.originalLanguage == "en")
    }

    @Test func tmdbShowDetailsWithNullsAndEmptyLists() throws {
        let show = try decode(TMDBShowDTO.self, Fixtures.tmdbShowDetailsMinimal)
        #expect(show.externalIDs?.imdbID == nil)
        #expect(show.posterPath == nil)
        #expect(show.networks.isEmpty)
        // Et le mapper en fait une série utilisable.
        let mapped = ShowMapper.map(tmdb: show, tvmaze: nil)
        #expect(mapped.status == .upcoming)
        #expect(mapped.network == nil)
    }

    @Test func tmdbSeasonWithUnairedEpisode() throws {
        let season = try decode(TMDBSeasonResponseDTO.self, Fixtures.tmdbSeason)
        #expect(season.episodes.count == 2)
        let aired = season.episodes[0]
        #expect(aired.seasonNumber == 8 && aired.episodeNumber == 1)
        #expect(aired.airDate == "2019-04-14")
        #expect(aired.runtime == 54)
        let unaired = season.episodes[1]
        #expect(unaired.airDate == nil)
        #expect(unaired.runtime == nil)
        #expect(unaired.stillPath == nil)
    }

    @Test func tmdbSearchResults() throws {
        let response = try decode(TMDBSearchResponseDTO.self, Fixtures.tmdbSearchResults)
        #expect(response.results.map(\.id) == [1399, 22980])
        #expect(response.results[1].posterPath == nil)
        // Le filtre de Home s'applique bien aux données décodées.
        #expect(response.results.filter(ShowRepository.isRecommendable).map(\.id) == [1399])
    }

    @Test func tmdbWatchProvidersThroughMapper() throws {
        let dto = try decode(TMDBWatchProvidersDTO.self, Fixtures.tmdbWatchProviders)
        #expect(dto.results["CA"]?.rent == nil)
        let canada = WatchAvailabilityMapper.map(dto: dto, region: "CA")
        #expect(canada.providerNames == ["Crave", "Apple TV", "Google Play Movies"])
        let us = WatchAvailabilityMapper.map(dto: dto, region: "US")
        #expect(us.providerNames == ["Max"])
        // Pays proposés dans le menu de la fiche : ceux qui ont au moins un diffuseur.
        #expect(Set(canada.availableRegions) == Set(dto.results.filter { _, region in
            !region.providersInDisplayOrder.isEmpty
        }.keys))
        #expect(canada.availableRegions.contains("CA"))
        #expect(canada.availableRegions.contains("US"))
    }

    @Test func tvmazeShow() throws {
        let show = try decode(TVmazeShowDTO.self, Fixtures.tvmazeLookup)
        #expect(show.id == 82)
        #expect(show.status == "Ended")
    }

    @Test func tvmazeEpisodesWithSpecial() throws {
        let episodes = try decode([TVmazeEpisodeDTO].self, Fixtures.tvmazeEpisodes)
        #expect(episodes.count == 2)
        #expect(episodes[0].number == 1)
        #expect(episodes[0].airstamp == "2019-04-15T01:00:00+00:00")
        #expect(episodes[1].number == nil)
        #expect(episodes[1].airstamp == nil)
    }

    /// Bout en bout : JSON réels des deux API jusqu'au modèle Episode.
    @Test func realEpisodeGetsTVmazePreciseTime() throws {
        let tmdb = try decode(TMDBSeasonResponseDTO.self, Fixtures.tmdbSeason).episodes[0]
        let tvmaze = try decode([TVmazeEpisodeDTO].self, Fixtures.tvmazeEpisodes)[0]
        let episode = EpisodeMapper.map(tmdb: tmdb, tvmaze: tvmaze, showID: "1399")
        #expect(episode.hasPreciseTime)
        #expect(episode.airDate == ISO8601DateFormatter().date(from: "2019-04-15T01:00:00Z"))
        #expect(episode.runtimeMinutes == 54)
        #expect(episode.id == "1399-s8e1")
    }
}
