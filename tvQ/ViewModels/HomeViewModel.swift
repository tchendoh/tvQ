import Foundation
import Observation

/// Charge les listes de découverte TMDB pour la page Accueil — pas de métrique
/// propre à tvQ ici (voir discussion sur Tendances-interne, mise de côté tant
/// qu'il n'y a pas assez d'utilisateurs pour que ça ait du sens).
@Observable
final class HomeViewModel {
    private(set) var trending: [ShowSummary] = []
    private(set) var onTheAir: [ShowSummary] = []
    private(set) var airingToday: [ShowSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let showRepository: ShowRepository
    private var loadTask: Task<Void, Never>?

    init(showRepository: ShowRepository = ShowRepository()) {
        self.showRepository = showRepository
    }

    var isEmpty: Bool {
        trending.isEmpty && onTheAir.isEmpty && airingToday.isEmpty
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            // Les trois listes sont indépendantes les unes des autres — en
            // parallèle plutôt que séquentiel, même raisonnement que partout
            // ailleurs dans l'app (MyShowsViewModel, ScheduleRepository).
            // Chacune est best-effort (try?) : un échec sur une seule liste
            // (ex. un endpoint TMDB temporairement indisponible) ne doit pas
            // vider les deux autres, qui peuvent très bien avoir réussi.
            async let trendingResult = try? showRepository.trendingShows()
            async let onTheAirResult = try? showRepository.onTheAirShows()
            async let airingTodayResult = try? showRepository.airingTodayShows()

            let (trending, onTheAir, airingToday) = await (trendingResult, onTheAirResult, airingTodayResult)
            if Task.isCancelled { return }

            self.trending = trending ?? []
            self.onTheAir = onTheAir ?? []
            self.airingToday = airingToday ?? []

            if trending == nil, onTheAir == nil, airingToday == nil {
                errorMessage = String(localized: "Couldn't load shows to discover. Check your connection and try again.")
            }
        }
    }
}
