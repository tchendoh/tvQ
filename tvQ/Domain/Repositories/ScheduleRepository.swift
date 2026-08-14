import Foundation

/// Source de l'horaire de diffusion. Implémentation concrète dans Data :
/// s'appuie sur TVmaze quand résolu, se rabat sur les dates TMDB sinon.
protocol ScheduleRepository {
    /// Liste complète des épisodes d'une série. Prend le Show complet (pas juste
    /// son ID) car il faut le tmdbID pour TMDB et le tvmazeID pour l'horaire précis.
    func getEpisodes(for show: Show) async throws -> [Episode]

    /// Épisodes à venir, toutes séries confondues, triés par date — utilisé pour la timeline.
    func getUpcomingEpisodes(for shows: [Show]) async throws -> [Episode]

    /// Même résultat que getUpcomingEpisodes(for:), avec en plus le décompte
    /// par palier de cache (combien de séries ont été servies depuis le disque
    /// local / Firestore partagé / l'API fraîche) — utilisé uniquement pour le
    /// diagnostic de performance de l'écran Schedule (voir ScheduleLoadMetrics).
    func getUpcomingEpisodesWithTiers(for shows: [Show]) async throws -> (episodes: [Episode], tiers: ScheduleLoadMetrics.TierBreakdown)
}

extension ScheduleRepository {
    func getUpcomingEpisodesWithTiers(for shows: [Show]) async throws -> (episodes: [Episode], tiers: ScheduleLoadMetrics.TierBreakdown) {
        (try await getUpcomingEpisodes(for: shows), ScheduleLoadMetrics.TierBreakdown())
    }
}
