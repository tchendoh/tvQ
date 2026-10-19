import Foundation
import Observation

/// Résout les Show complets à partir des IDs suivis (FollowedShowsStore).
/// Ne connaît que ShowRepository : aucune référence à Firestore ici.
@Observable
final class MyShowsViewModel {
    private(set) var shows: [Show] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let showRepository: ShowRepository
    private var loadTask: Task<Void, Never>?

    init(showRepository: ShowRepository = .shared) {
        self.showRepository = showRepository
    }

    /// Deux groupes seulement : les statuts « en cours », « entre deux saisons » ou
    /// « à venir » de TMDB et TVmaze sont trop peu fiables pour un classement plus
    /// fin. « Terminée » est le seul qui l'est assez (série finie ou annulée).
    var ongoingShows: [Show] {
        shows.filter { $0.status != .ended }
    }

    var endedShows: [Show] {
        shows.filter { $0.status == .ended }
    }

    /// Appelée depuis .task(id: followedShowsStore.followedShowIDs) — se relance
    /// automatiquement à chaque follow/unfollow.
    ///
    /// reloadAll : re-résout toutes les séries plutôt que seulement les nouvelles
    /// (changement de langue de contenu). Les cartes déjà affichées restent visibles
    /// jusqu'à ce que les nouvelles les remplacent d'un coup.
    func load(showIDs: Set<String>, reloadAll: Bool = false) {
        loadTask?.cancel()

        guard !showIDs.isEmpty else {
            shows = []
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
        let missingIDs = reloadAll ? showIDs : showIDs.subtracting(currentIDs)

        guard !missingIDs.isEmpty else { return }

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
                shows = ((reloadAll ? [] : shows) + resolved).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your shows. Check your connection and try again.")
                }
            }
        }
    }
}
