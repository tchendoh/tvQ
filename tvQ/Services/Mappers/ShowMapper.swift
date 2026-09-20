import Foundation

/// Combine un DTO TMDB (métadonnées) et un DTO TVmaze optionnel (statut de diffusion)
/// pour produire l'entité Domain `Show`. C'est le seul endroit de l'app qui connaît
/// à la fois la forme de TMDB et celle de TVmaze.
enum ShowMapper {
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!

    static func map(tmdb: TMDBShowDTO, tvmaze: TVmazeShowDTO?) -> Show {
        Show(
            tmdbID: tmdb.id,
            imdbID: tmdb.externalIDs?.imdbID,
            tvmazeID: tvmaze?.id,
            title: tmdb.name,
            overview: tmdb.overview,
            posterURL: tmdb.posterPath.map { imageBaseURL.appendingPathComponent($0) },
            backdropURL: tmdb.backdropPath.map { imageBaseURL.appendingPathComponent($0) },
            genres: tmdb.genres.map(\.name),
            network: tmdb.networks.first?.name,
            status: mapStatus(tmdbStatus: tmdb.status, tvmazeStatus: tvmaze?.status),
            numberOfSeasons: tmdb.numberOfSeasons,
            originalLanguage: tmdb.originalLanguage
        )
    }

    /// TVmaze est mis à jour plus rapidement sur les changements de statut (retour de saison,
    /// annulation) — on le priorise quand disponible, TMDB sert de repli.
    private static func mapStatus(tmdbStatus: String, tvmazeStatus: String?) -> ShowStatus {
        let source = tvmazeStatus ?? tmdbStatus
        switch source.lowercased() {
        case "running", "returning series", "in production":
            return .running
        case "ended", "canceled", "cancelled":
            return .ended
        case "upcoming", "planned", "to be determined":
            return .upcoming
        default:
            return .unknown
        }
    }
}
