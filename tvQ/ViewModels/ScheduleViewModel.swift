import Foundation
import Observation

/// Pilote l'écran "Schedule" : résout les Show complets à partir des IDs suivis
/// (comme MyShowsViewModel — nécessaire ici pour le status ShowStatus, qui sert
/// à filtrer les séries .ended dans ScheduleRepository.getUpcomingEpisodes),
/// puis récupère les épisodes récemment diffusés et à venir, toutes séries
/// confondues, triés par date.
@Observable
final class ScheduleViewModel {
    /// Associe chaque épisode à la série dont il provient — nécessaire pour
    /// l'affichage (titre, affiche) puisque Episode ne connaît que showID.
    struct ScheduleItem: Identifiable, Equatable {
        let episode: Episode
        let show: Show
        var id: String { episode.id }
    }

    private(set) var items: [ScheduleItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?


    private let showRepository: ShowRepository
    private let scheduleRepository: ScheduleRepository
    private var loadTask: Task<Void, Never>?

    init(
        showRepository: ShowRepository = .shared,
        scheduleRepository: ScheduleRepository = .shared
    ) {
        self.showRepository = showRepository
        self.scheduleRepository = scheduleRepository
    }

    /// Appelée depuis .task(id: followedShowsStore.followedShowIDs) — se relance
    /// automatiquement à chaque follow/unfollow, comme MyShowsViewModel.load.
    func load(showIDs: Set<String>) {
        loadTask?.cancel()

        guard !showIDs.isEmpty else {
            items = []
            errorMessage = nil
            return
        }

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                // Résolution en parallèle plutôt que séquentielle : le vrai goulot
                // n'était pas l'horaire lui-même, déjà mis en cache, mais cette
                // résolution de Show en boucle.
                let tmdbIDs = showIDs.compactMap { Int($0) }
                let shows = try await withThrowingTaskGroup(of: Show.self) { group in
                    for tmdbID in tmdbIDs {
                        group.addTask { try await self.showRepository.getShow(tmdbID: tmdbID) }
                    }
                    var resolved: [Show] = []
                    for try await show in group {
                        resolved.append(show)
                    }
                    return resolved
                }
                if Task.isCancelled { return }

                let showsByID = Dictionary(uniqueKeysWithValues: shows.map { ($0.id, $0) })
                let episodes = try await scheduleRepository.getUpcomingEpisodes(for: shows)
                if Task.isCancelled { return }

                items = episodes.compactMap { episode in
                    guard let show = showsByID[episode.showID] else { return nil }
                    return ScheduleItem(episode: episode, show: show)
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your upcoming episodes. Check your connection and try again.")
                }
            }
        }
    }

    /// À la déconnexion (voir RootView) : le view model vit dans RootView, donc
    /// survit à la déconnexion. Annule le chargement en cours et vide l'état pour
    /// qu'un autre compte ne voie pas l'horaire du précédent.
    func clear() {
        loadTask?.cancel()
        loadTask = nil
        items = []
        errorMessage = nil
        isLoading = false
    }

    /// Pour .refreshable (voir ScheduleView) : `load` lance une Task et retourne
    /// aussitôt (utilisé depuis .task(id:), qui ne peut pas attendre), donc on a
    /// besoin d'une variante awaitable qui bloque jusqu'à la fin du chargement —
    /// sans ça le rafraîchissement disparaîtrait avant même que la requête parte.
    func refresh(showIDs: Set<String>) async {
        load(showIDs: showIDs)
        await loadTask?.value
    }
}
