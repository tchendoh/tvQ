import Foundation
import Observation

/// Pilote l'écran de fiche détail d'une série. Charge le Show complet (résolution
/// TMDB + TVmaze) puis ses épisodes. Ne connaît que les protocoles ShowRepository
/// et ScheduleRepository — testable avec de faux repositories sans appel réseau.
@Observable
final class ShowDetailViewModel {
    private(set) var show: Show?
    private(set) var episodesBySeason: [Int: [Episode]] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let tmdbID: Int

    private let showRepository: ShowRepository
    private let scheduleRepository: ScheduleRepository
    private var loadTask: Task<Void, Never>?

    init(
        tmdbID: Int,
        showRepository: ShowRepository = RemoteShowRepository(),
        scheduleRepository: ScheduleRepository = RemoteScheduleRepository()
    ) {
        self.tmdbID = tmdbID
        self.showRepository = showRepository
        self.scheduleRepository = scheduleRepository
    }

    var sortedSeasonNumbers: [Int] {
        episodesBySeason.keys.sorted()
    }

    /// Appelée depuis .task sur la vue. Charge la série puis ses épisodes ;
    /// un échec sur les épisodes n'empêche pas d'afficher les métadonnées déjà résolues.
    func load() {
        guard show == nil, !isLoading else { return }

        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let resolvedShow = try await showRepository.getShow(tmdbID: tmdbID)
                guard !Task.isCancelled else { return }
                show = resolvedShow

                let episodes = try await scheduleRepository.getEpisodes(for: resolvedShow)
                guard !Task.isCancelled else { return }
                episodesBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load this show. Check your connection and try again.")
                }
            }
        }
    }
}
