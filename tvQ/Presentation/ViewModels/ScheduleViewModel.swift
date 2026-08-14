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

    /// Chronométrage du dernier chargement réussi — affiché dans ScheduleView
    /// à des fins de diagnostic (voir ScheduleLoadMetrics). nil avant le
    /// premier chargement, ou si le dernier a échoué en cours de route.
    private(set) var lastLoadMetrics: ScheduleLoadMetrics?

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

            let overallStart = ContinuousClock.now

            do {
                // Résolution en parallèle plutôt que séquentielle — voir
                // MyShowsViewModel.load pour le même changement et son
                // raisonnement (le vrai goulot n'était pas l'horaire lui-même,
                // déjà mis en cache, mais cette résolution de Show en boucle).
                let showsStart = ContinuousClock.now
                let tmdbIDs = showIDs.compactMap { Int($0) }
                let showResults = try await withThrowingTaskGroup(of: (show: Show, tier: CacheTier).self) { group in
                    for tmdbID in tmdbIDs {
                        group.addTask { try await self.showRepository.getShowWithTier(tmdbID: tmdbID) }
                    }
                    var resolved: [(show: Show, tier: CacheTier)] = []
                    for try await result in group {
                        resolved.append(result)
                    }
                    return resolved
                }
                let showsDuration = ContinuousClock.now - showsStart
                if Task.isCancelled { return }

                var showsByTier = ScheduleLoadMetrics.TierBreakdown()
                for result in showResults {
                    showsByTier.record(result.tier)
                }
                let shows = showResults.map(\.show)

                let showsByID = Dictionary(uniqueKeysWithValues: shows.map { ($0.id, $0) })
                let episodesStart = ContinuousClock.now
                let (episodes, episodesByTier) = try await scheduleRepository.getUpcomingEpisodesWithTiers(for: shows)
                let episodesDuration = ContinuousClock.now - episodesStart
                if Task.isCancelled { return }

                items = episodes.compactMap { episode in
                    guard let show = showsByID[episode.showID] else { return nil }
                    return ScheduleItem(episode: episode, show: show)
                }

                lastLoadMetrics = ScheduleLoadMetrics(
                    showsDuration: showsDuration,
                    episodesDuration: episodesDuration,
                    totalDuration: ContinuousClock.now - overallStart,
                    showsByTier: showsByTier,
                    episodesByTier: episodesByTier
                )
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your upcoming episodes. Check your connection and try again.")
                }
            }
        }
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
