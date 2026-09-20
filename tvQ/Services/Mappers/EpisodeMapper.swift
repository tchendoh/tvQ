import Foundation

/// Combine un DTO TMDB (date seule, toujours disponible) et un DTO TVmaze optionnel
/// (timestamp précis) pour produire l'entité Domain `Episode`.
enum EpisodeMapper {
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    static func map(tmdb: TMDBEpisodeDTO, tvmaze: TVmazeEpisodeDTO?, showID: String) -> Episode {
        let tmdbDate = tmdb.airDate.flatMap { dateOnlyFormatter.date(from: $0) }
        let tvmazeStamp = tvmaze?.airstamp.flatMap { isoFormatter.date(from: $0) }

        return Episode(
            id: "\(showID)-s\(tmdb.seasonNumber)e\(tmdb.episodeNumber)",
            showID: showID,
            seasonNumber: tmdb.seasonNumber,
            episodeNumber: tmdb.episodeNumber,
            title: tmdb.name,
            overview: tmdb.overview,
            stillImageURL: tmdb.stillPath.map {
                ShowMapper.imageBaseURL.appendingPathComponent($0)
            },
            airDate: tvmazeStamp ?? tmdbDate,
            hasPreciseTime: tvmazeStamp != nil
        )
    }
}
