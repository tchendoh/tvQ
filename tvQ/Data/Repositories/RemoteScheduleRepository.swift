import Foundation

/// Implémentation concrète de ScheduleRepository : combine les épisodes TMDB
/// (source de vérité pour le contenu — titres, synopsis, saisons) avec les
/// timestamps précis de TVmaze quand la série y est résolue.
final class RemoteScheduleRepository: ScheduleRepository {
    private let tmdbClient: TMDBClient
    private let tvmazeClient: TVmazeClient

    init(tmdbClient: TMDBClient = TMDBClient(), tvmazeClient: TVmazeClient = TVmazeClient()) {
        self.tmdbClient = tmdbClient
        self.tvmazeClient = tvmazeClient
    }

    func getEpisodes(for show: Show) async throws -> [Episode] {
        // Même logique que ShowRepository.getShow — voir discussion sur la langue d'origine.
        let episodeLanguage = AppSettings.useOriginalLanguage ? show.originalLanguage : nil

        // TMDB : un appel par saison, il n'y a pas d'endpoint "tous les épisodes" en un coup.
        var tmdbEpisodes: [TMDBEpisodeDTO] = []
        for season in 1...max(show.numberOfSeasons, 1) {
            let episodes = try await tmdbClient.fetchEpisodes(seriesID: show.tmdbID, season: season, language: episodeLanguage)
            tmdbEpisodes.append(contentsOf: episodes)
        }

        // TVmaze : un seul appel retourne tous les épisodes de toutes les saisons.
        var tvmazeEpisodes: [TVmazeEpisodeDTO] = []
        if let tvmazeID = show.tvmazeID {
            tvmazeEpisodes = try await tvmazeClient.fetchEpisodes(showID: tvmazeID)
        }

        return tmdbEpisodes.map { tmdbEpisode in
            let matchingTVmazeEpisode = tvmazeEpisodes.first {
                $0.season == tmdbEpisode.seasonNumber && $0.number == tmdbEpisode.episodeNumber
            }
            return EpisodeMapper.map(tmdb: tmdbEpisode, tvmaze: matchingTVmazeEpisode, showID: show.id)
        }
    }

    func getUpcomingEpisodes(for shows: [Show]) async throws -> [Episode] {
        let now = Date()

        // Un appel réseau par série suivie. Pour un usage personnel (quelques dizaines
        // de séries suivies au plus), c'est largement acceptable ; à revisiter avec du
        // cache si tvQ grossit beaucoup.
        var allUpcoming: [Episode] = []
        for show in shows {
            let episodes = try await getEpisodes(for: show)
            let upcoming = episodes.filter { episode in
                guard let date = episode.bestAvailableDate else { return false }
                return date >= now
            }
            allUpcoming.append(contentsOf: upcoming)
        }

        return allUpcoming.sorted { lhs, rhs in
            (lhs.bestAvailableDate ?? .distantFuture) < (rhs.bestAvailableDate ?? .distantFuture)
        }
    }
}
