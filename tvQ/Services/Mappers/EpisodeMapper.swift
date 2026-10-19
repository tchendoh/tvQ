import Foundation

/// Combine un DTO TMDB (date seule, toujours disponible) et un DTO TVmaze optionnel
/// (timestamp précis) pour produire le modèle `Episode`.
enum EpisodeMapper {
    /// « 2026-07-15 » (TMDB), lu à minuit UTC : la date seule, sans heure. Les
    /// styles de format sont des valeurs Sendable, contrairement à DateFormatter.
    private static let dateOnly = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    /// « 2026-07-15T20:00:00-04:00 » (TVmaze), avec son décalage horaire.
    private static let timestamp = Date.ISO8601FormatStyle()

    static func map(tmdb: TMDBEpisodeDTO, tvmaze: TVmazeEpisodeDTO?, showID: String) -> Episode {
        let tmdbDate = tmdb.airDate.flatMap { try? Date($0, strategy: dateOnly) }
        let tvmazeStamp = tvmaze?.airstamp.flatMap { try? Date($0, strategy: timestamp) }

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
            hasPreciseTime: tvmazeStamp != nil,
            runtimeMinutes: tvmaze?.runtime ?? tmdb.runtime
        )
    }
}
