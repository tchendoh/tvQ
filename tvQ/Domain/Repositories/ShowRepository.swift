import Foundation

/// Source des métadonnées et de la recherche de séries.
/// Implémentation concrète dans Data : orchestre TMDB (métadonnées/images)
/// et la résolution de l'IMDB ID vers TVmaze.
protocol ShowRepository {
    /// TMDB ne retourne pas l'IMDB ID sur cet endpoint, d'où le résumé léger
    /// plutôt qu'un Show complet — voir ShowSummary pour l'explication.
    func search(query: String) async throws -> [ShowSummary]

    /// Résout les métadonnées complètes + l'IMDB ID pivot + l'horaire TVmaze
    /// pour une série identifiée par son ID TMDB.
    func getShow(tmdbID: Int) async throws -> Show

    /// Trois listes de découverte toutes faites de TMDB — pour la page Accueil.
    /// Résumé léger comme search(), pas de Show complet nécessaire tant que
    /// l'utilisateur n'a pas ouvert la fiche.
    func trendingShows() async throws -> [ShowSummary]
    func onTheAirShows() async throws -> [ShowSummary]
    func airingTodayShows() async throws -> [ShowSummary]
}
