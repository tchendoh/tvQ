import Foundation

/// Service réseau brut pour TMDB : ne retourne que des DTOs, jamais de modèles.
/// L'orchestration (combiner avec TVmaze, mapper vers Show/Episode) se fait dans
/// ShowRepository / ScheduleRepository, pas ici.
struct TMDBService {
    private let networkService: NetworkService
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    /// Langue imposée à la construction (tests) ; nil pour suivre le réglage.
    private let languageOverride: String?

    /// Langue des réponses TMDB (format ISO, ex. "en-US", "fr-CA"). Lue à chaque
    /// requête plutôt qu'une fois à la construction : les repositories sont partagés
    /// pour toute la durée de l'app, et un changement dans Settings doit s'appliquer
    /// aux requêtes suivantes sans redémarrer.
    private var language: String {
        languageOverride ?? AppSettings.contentLanguage
    }

    init(networkService: NetworkService = NetworkService(), language: String? = nil) {
        self.networkService = networkService
        self.languageOverride = language
    }

    /// Toutes les requêtes TMDB passent par ici : ajoute l'en-tête d'authentification
    /// puis délègue à NetworkService. Le type décodé est déduit de l'appelant.
    /// Jeton refusé (401, ex. après une rotation dans Remote Config) : on va chercher
    /// la valeur actuelle et on réessaie une fois, sans attendre un relancement.
    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let token = try await TMDBToken.shared.value()
        do {
            return try await send(url, token: token)
        } catch NetworkError.httpStatus(401) {
            guard let fresh = try await TMDBToken.shared.refreshAfterRejection(of: token) else {
                throw NetworkError.httpStatus(401)
            }
            return try await send(url, token: fresh)
        }
    }

    private func send<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await networkService.fetch(request, as: T.self)
    }

    func searchShows(query: String) async throws -> [TMDBSearchResultDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search/tv"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: language)
        ]
        let response: TMDBSearchResponseDTO = try await get(components.url!)
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
        return try await get(components.url!)
    }

    func fetchEpisodes(seriesID: Int, season: Int, language: String? = nil) async throws -> [TMDBEpisodeDTO] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("tv/\(seriesID)/season/\(season)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "language", value: language ?? self.language)]
        let response: TMDBSeasonResponseDTO = try await get(components.url!)
        return response.episodes
    }

    /// Trois listes toutes faites de TMDB, pour la page Accueil (découverte) —
    /// à ne pas confondre avec une métrique propre à tvQ.

    /// "week" plutôt que "day" : plus stable d'une ouverture d'app à l'autre.
    func fetchTrendingTV(timeWindow: String = "week") async throws -> [TMDBSearchResultDTO] {
        try await fetchList(path: "trending/tv/\(timeWindow)")
    }

    /// Séries ayant un épisode prévu dans les 7 prochains jours.
    func fetchOnTheAirTV() async throws -> [TMDBSearchResultDTO] {
        try await fetchList(path: "tv/on_the_air")
    }

    /// Séries ayant un épisode qui sort aujourd'hui même.
    func fetchAiringTodayTV() async throws -> [TMDBSearchResultDTO] {
        try await fetchList(path: "tv/airing_today")
    }

    /// `watch_region` est ignoré par TMDB sur cet endpoint précis : la réponse
    /// contient déjà toutes les régions, filtrées côté appelant (voir
    /// WatchProvidersMapper). Pas de paramètre `language` non plus — les noms
    /// de diffuseurs (`provider_name`) ne sont pas localisés par TMDB.
    func fetchWatchProviders(seriesID: Int) async throws -> TMDBWatchProvidersDTO {
        let url = baseURL.appendingPathComponent("tv/\(seriesID)/watch/providers")
        return try await get(url)
    }

    private func fetchList(path: String) async throws -> [TMDBSearchResultDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "language", value: language)]
        let response: TMDBSearchResponseDTO = try await get(components.url!)
        return response.results
    }
}
