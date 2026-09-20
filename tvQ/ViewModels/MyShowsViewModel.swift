import Foundation
import Observation

/// Résout les Show complets à partir des IDs suivis (FollowedShowsStore).
/// Ne connaît que ShowRepository et ScheduleRepository — aucune référence à
/// Firestore ici.
@Observable
final class MyShowsViewModel {
    private(set) var shows: [Show] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// IDs des séries ayant un épisode diffusé récemment ou à venir (même fenêtre
    /// que l'horaire "À venir", voir ScheduleRepository.getUpcomingEpisodes).
    /// Sert à distinguer "en cours" de "en pause" pour les séries non terminées.
    private(set) var upcomingShowIDs: Set<String> = []

    private let showRepository: ShowRepository
    private let scheduleRepository: ScheduleRepository
    private var loadTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?

    init(
        showRepository: ShowRepository = ShowRepository(),
        scheduleRepository: ScheduleRepository = ScheduleRepository()
    ) {
        self.showRepository = showRepository
        self.scheduleRepository = scheduleRepository
    }

    /// Séries dont le statut dit explicitement "pas encore diffusée" — info fiable
    /// directement de TMDB/TVmaze, prioritaire sur l'heuristique d'épisode à venir
    /// (une série tout juste annoncée aurait sinon pu atterrir dans "Saison terminée"
    /// à tort, faute d'avoir jamais eu de saison).
    var upcomingShows: [Show] {
        shows.filter { $0.status == .upcoming }
    }

    /// Séries en diffusion active : pas terminées, pas "à venir", et avec un
    /// épisode récent/à venir dans la fenêtre vérifiée.
    var currentShows: [Show] {
        shows.filter { $0.status != .ended && $0.status != .upcoming && upcomingShowIDs.contains($0.id) }
    }

    /// Séries pas terminées, déjà diffusées, mais sans épisode récent/à venir
    /// connu — le cas le plus courant est "entre deux saisons", mais ça peut aussi
    /// être une donnée d'horaire manquante ou pas encore à jour.
    var seasonEndedShows: [Show] {
        shows.filter { $0.status != .ended && $0.status != .upcoming && !upcomingShowIDs.contains($0.id) }
    }

    var endedShows: [Show] {
        shows.filter { $0.status == .ended }
    }

    /// Appelée depuis .task(id: followedShowsStore.followedShowIDs) — se relance
    /// automatiquement à chaque follow/unfollow.
    func load(showIDs: Set<String>) {
        loadTask?.cancel()

        guard !showIDs.isEmpty else {
            shows = []
            upcomingShowIDs = []
            errorMessage = nil
            return
        }

        // Retrait immédiat des séries qui ne sont plus suivies (unfollow) — purement
        // local, indépendant du réseau. Avant ce correctif, tout l'ensemble était
        // re-résolu à chaque changement et l'affichage n'était mis à jour que si TOUS
        // les appels réussissaient : un échec réseau sur une série qui n'avait rien à
        // voir avec l'unfollow (ex. une autre série suivie momentanément injoignable)
        // faisait échouer tout le lot, et la série retirée restait affichée alors
        // qu'elle avait bien disparu de FollowedShowsStore.
        shows.removeAll { !showIDs.contains($0.id) }

        // On ne va chercher que ce qui manque encore à l'affichage (nouveaux follows).
        let currentIDs = Set(shows.map(\.id))
        let missingIDs = showIDs.subtracting(currentIDs)

        guard !missingIDs.isEmpty else {
            refreshUpcomingStatus()
            return
        }

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                // Résolution en parallèle plutôt que séquentielle — avec une
                // centaine de séries suivies, un aller-retour à la fois faisait
                // traîner l'écran plusieurs secondes. getShow(tmdbID:) passe par
                // les caches de ShowRepository, donc la plupart de ces appels
                // ne touchent même pas le réseau.
                let tmdbIDs = missingIDs.compactMap { Int($0) }
                let resolved = try await withThrowingTaskGroup(of: Show.self) { group in
                    for tmdbID in tmdbIDs {
                        group.addTask { try await self.showRepository.getShow(tmdbID: tmdbID) }
                    }
                    var newShows: [Show] = []
                    for try await show in group {
                        newShows.append(show)
                    }
                    return newShows
                }
                if Task.isCancelled { return }
                shows = (shows + resolved).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                refreshUpcomingStatus()
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your shows. Check your connection and try again.")
                }
            }
        }
    }

    /// Détermine quelles séries (parmi celles pas terminées) ont un épisode dans
    /// la fenêtre "récent/à venir" — best-effort : un échec ici n'affiche pas
    /// d'erreur, il laisse simplement toutes les séries non résolues dans "en pause".
    private func refreshUpcomingStatus() {
        scheduleTask?.cancel()
        let candidates = shows
        scheduleTask = Task {
            guard let episodes = try? await scheduleRepository.getUpcomingEpisodes(for: candidates) else { return }
            if Task.isCancelled { return }
            upcomingShowIDs = Set(episodes.map(\.showID))
        }
    }
}
