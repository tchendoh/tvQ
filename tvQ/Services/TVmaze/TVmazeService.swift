import Foundation

/// Service réseau brut pour TVmaze : ne retourne que des DTOs.
/// Pas de clé API requise côté TVmaze (contrairement à TMDB).
struct TVmazeService {
    private let networkService: NetworkService
    private let baseURL = URL(string: "https://api.tvmaze.com")!

    init(networkService: NetworkService = NetworkService()) {
        self.networkService = networkService
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try await networkService.fetch(URLRequest(url: url), as: T.self)
    }

    /// `/lookup/shows?imdb=:id` répond par une redirection HTTP 301 vers la fiche
    /// TVmaze — URLSession la suit automatiquement, donc on reçoit directement le JSON
    /// du show. Si TVmaze n'a pas cette série, on reçoit un 404 : on retourne nil
    /// plutôt que de propager une erreur, car l'absence de TVmaze est un cas normal
    /// (fallback sur les dates TMDB dans le mapper).
    func lookupShow(imdbID: String) async throws -> TVmazeShowDTO? {
        var components = URLComponents(url: baseURL.appendingPathComponent("lookup/shows"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "imdb", value: imdbID)]

        do {
            return try await get(components.url!)
        } catch NetworkError.httpStatus(let statusCode) where statusCode == 404 {
            return nil
        }
    }

    func fetchEpisodes(showID: Int) async throws -> [TVmazeEpisodeDTO] {
        let url = baseURL.appendingPathComponent("shows/\(showID)/episodes")
        return try await get(url)
    }
}
