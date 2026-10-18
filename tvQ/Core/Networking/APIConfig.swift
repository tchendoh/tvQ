import Foundation

/// Point d'accès unique aux clés d'API.
/// Le jeton TMDB n'est plus compilé dans l'app : il vient de Firebase Remote Config
/// (clé `tmdb_token`), ce qui permet une rotation depuis la console sans nouveau build.
/// Voir TMDBToken.
enum APIConfig {
    static func tmdbAPIKey() async throws -> String {
        try await TMDBToken.shared.value()
    }

    /// Après un refus du jeton par TMDB : nouveau jeton, ou nil s'il n'a pas changé.
    static func refreshTMDBAPIKey(rejected: String) async throws -> String? {
        try await TMDBToken.shared.refreshAfterRejection(of: rejected)
    }
}
