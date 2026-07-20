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
        showRepository: ShowRepository = RemoteShowRepository(),
        scheduleRepository: ScheduleRepository = RemoteScheduleRepository()
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
                // Résolution en parallèle plutôt que séquentielle — voir
                // MyShowsViewModel.load pour le même changement et son
                // raisonnement (le vrai goulot n'était pas l'horaire lui-même,
                // déjà mis en cache, mais cette résolution de Show en boucle).
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
}
