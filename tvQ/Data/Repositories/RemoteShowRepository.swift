import Foundation

/// Implémentation concrète de ShowRepository : orchestre TMDBClient et TVmazeClient,
/// puis délègue à ShowMapper la construction de l'entité Domain finale.
/// C'est le seul endroit (avec RemoteScheduleRepository) qui connaît l'existence
/// des deux sources externes — le reste de l'app ne voit que le protocole.
final class RemoteShowRepository: ShowRepository {
    private let tmdbClient: TMDBClient
    private let tvmazeClient: TVmazeClient

    init(tmdbClient: TMDBClient = TMDBClient(), tvmazeClient: TVmazeClient = TVmazeClient()) {
        self.tmdbClient = tmdbClient
        self.tvmazeClient = tvmazeClient
    }

    func search(query: String) async throws -> [ShowSummary] {
        let results = try await tmdbClient.searchShows(query: query)
        return results.map { dto in
            ShowSummary(
                tmdbID: dto.id,
                title: dto.name,
                overview: dto.overview,
                posterURL: dto.posterPath.map { ShowMapper.imageBaseURL.appendingPathComponent($0) }
            )
        }
    }

    func getShow(tmdbID: Int) async throws -> Show {
        var tmdbShow = try await tmdbClient.fetchShowDetails(id: tmdbID)

        // Si l'utilisateur préfère la langue d'origine et qu'elle diffère de la langue
        // de contenu par défaut, on refait un appel ciblé — TMDB ne garantit pas un
        // repli fiable vers la langue d'origine sur cet endpoint (voir discussion).
        if AppSettings.useOriginalLanguage, !AppSettings.contentLanguage.hasPrefix(tmdbShow.originalLanguage) {
            tmdbShow = try await tmdbClient.fetchShowDetails(id: tmdbID, language: tmdbShow.originalLanguage)
        }

        // Pas d'erreur si l'IMDB ID est absent : la série reste utilisable,
        // elle perd juste l'horaire précis TVmaze (repli sur les dates TMDB).
        var tvmazeShow: TVmazeShowDTO?
        if let imdbID = tmdbShow.externalIDs?.imdbID {
            tvmazeShow = try await tvmazeClient.lookupShow(imdbID: imdbID)
        }

        return ShowMapper.map(tmdb: tmdbShow, tvmaze: tvmazeShow)
    }
}
