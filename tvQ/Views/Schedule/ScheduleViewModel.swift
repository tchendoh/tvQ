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

    /// Séries suivies du dernier `load` : nécessaires pour relire la copie locale
    /// quand elle change, sans attendre un nouvel appel de la vue.
    private var showIDs: Set<String> = []

    init(
        showRepository: ShowRepository = .shared,
        scheduleRepository: ScheduleRepository = .shared
    ) {
        self.showRepository = showRepository
        self.scheduleRepository = scheduleRepository
    }

    /// Appelée depuis .task(id: followedShowsStore.followedShowIDs) — se relance
    /// automatiquement à chaque follow/unfollow, comme MyShowsViewModel.load.
    ///
    /// L'écran affiche toujours la copie locale (SwiftData) : d'abord ce qu'elle contient
    /// déjà, sans attendre le réseau, puis ce que la synchronisation y ajoute. Les
    /// rafraîchissements en arrière-plan des repositories arrivent par LocalDataVersion
    /// (voir MainTabView, qui appelle reloadFromLocal).
    func load(showIDs: Set<String>) {
        loadTask?.cancel()
        self.showIDs = showIDs

        guard !showIDs.isEmpty else {
            items = []
            errorMessage = nil
            return
        }

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            // 1. Affichage immédiat de ce qui est déjà sur l'appareil.
            await reloadFromLocal()
            if Task.isCancelled { return }

            do {
                // 2. Résolution des séries en parallèle : locale si possible, réseau
                // seulement pour celles jamais synchronisées sur cet appareil.
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

                // 3. Épisodes manquants, puis relecture locale.
                try await scheduleRepository.ensureUpcomingEpisodes(for: shows)
                let episodes = try await scheduleRepository.localUpcomingEpisodes(for: shows)
                if Task.isCancelled { return }

                items = Self.makeItems(episodes: episodes, shows: shows)
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your upcoming episodes. Check your connection and try again.")
                }
            }
        }
    }

    /// Associe chaque épisode à sa série ; un épisode dont la série est absente est ignoré.
    private static func makeItems(episodes: [Episode], shows: [Show]) -> [ScheduleItem] {
        let showsByID = Dictionary(shows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return episodes.compactMap { episode in
            guard let show = showsByID[episode.showID] else { return nil }
            return ScheduleItem(episode: episode, show: show)
        }
    }

    // MARK: - Copie locale

    /// Relit l'horaire depuis SwiftData seulement : aucun appel réseau, donc aucun
    /// risque de boucle (une relecture ne provoque jamais de sauvegarde). Une série
    /// pas encore synchronisée est simplement absente jusqu'à son arrivée.
    ///
    /// Appelée par MainTabView à chaque changement de LocalDataVersion. Si une autre
    /// relecture a commencé entre-temps (tâche annulée), on n'écrase pas son résultat.
    func reloadFromLocal() async {
        let tmdbIDs = showIDs.compactMap { Int($0) }
        // Liste vide : c'est `load` (aucune série suivie) ou `clear` (déconnexion) qui vide.
        guard !tmdbIDs.isEmpty else { return }

        var shows: [Show] = []
        for tmdbID in tmdbIDs {
            if let show = await showRepository.localShow(tmdbID: tmdbID) {
                shows.append(show)
            }
        }
        guard let episodes = try? await scheduleRepository.localUpcomingEpisodes(for: shows),
              !Task.isCancelled else { return }
        items = Self.makeItems(episodes: episodes, shows: shows)
    }

    /// À la déconnexion (voir RootView) : le view model vit dans RootView, donc
    /// survit à la déconnexion. Annule le chargement en cours et vide l'état pour
    /// qu'un autre compte ne voie pas l'horaire du précédent.
    func clear() {
        loadTask?.cancel()
        loadTask = nil
        showIDs = []
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
