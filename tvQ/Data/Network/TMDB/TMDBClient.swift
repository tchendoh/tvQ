import Foundation

/// Client réseau brut pour TMDB : ne retourne que des DTOs, jamais d'entités Domain.
/// L'orchestration (combiner avec TVmaze, mapper vers Show/Episode) se fait dans
/// l'implémentation concrète de ShowRepository / ScheduleRepository, pas ici.
struct TMDBClient {
    private let httpClient: HTTPClient
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    /// Langue des réponses TMDB (format ISO, ex. "en-US", "fr-CA"), lue depuis les
    /// préférences locales de l'utilisateur (voir AppSettings / SettingsView).
    private let language: String

    init(httpClient: HTTPClient = URLSessionHTTPClient(), language: String = AppSettings.contentLanguage) {
        self.httpClient = httpClient
        self.language = language
    }

    private var authHeaders: [String: String] {
        ["Authorization": "Bearer \(APIConfig.tmdbAPIKey)"]
    }

    func searchShows(query: String) async throws -> [TMDBSearchResultDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search/tv"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: language)
        ]
        let response: TMDBSearchResponseDTO = try await httpClient.get(url: components.url!, headers: authHeaders)
        return response.results
    }

    /// `append_to_response=external_ids` évite un deuxième appel réseau juste pour l'IMDB ID.
    /// `language` permet de passer outre la préférence par défaut (ex. langue d'origine).
    func fetchShowDetails(id: Int, language: String? = nil) async throws -> TMDBShowDTO {
        var components = URLComponents(url: baseURL.appendingPathComponent("tv/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "append_to_response", value: "external_ids"),
            URLQueryItem(name: "language", value: language ?? self.language)
        ]
        return try await httpClient.get(url: components.url!, headers: authHeaders)
    }

    func fetchEpisodes(seriesID: Int, season: Int, language: String? = nil) async throws -> [TMDBEpisodeDTO] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("tv/\(seriesID)/season/\(season)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "language", value: language ?? self.language)]
        let response: TMDBSeasonResponseDTO = try await httpClient.get(url: components.url!, headers: authHeaders)
        return response.episodes
    }
}
