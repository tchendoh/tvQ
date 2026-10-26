import Foundation
import Observation

/// Charge le contenu de la page Accueil : deux listes toutes faites de TMDB
/// (tendances, diffusées aujourd'hui) et, quand il y a assez d'utilisateurs, les
/// séries les plus suivies sur tvQ (document trends/current, écrit par le script
/// du Mac mini).
@Observable
final class HomeViewModel {
    private(set) var popularOnTvQ: [ShowSummary] = []
    private(set) var trending: [ShowSummary] = []
    private(set) var airingToday: [ShowSummary] = []
    /// Carte d'invitation à la place de « Popular on tvQ » : bêta seulement, et
    /// seulement tant que le classement n'a pas atteint son seuil.
    private(set) var showsTvQInvite = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let showRepository: ShowRepository
    private let loadTrends: @Sendable () async throws -> Trends?
    private let isBeta: @Sendable () async -> Bool
    private var loadTask: Task<Void, Never>?

    init(
        showRepository: ShowRepository = .shared,
        loadTrends: @escaping @Sendable () async throws -> Trends? = { try await TrendsService().current() },
        isBeta: @escaping @Sendable () async -> Bool = AppDistribution.isBeta
    ) {
        self.showRepository = showRepository
        self.loadTrends = loadTrends
        self.isBeta = isBeta
    }

    var isEmpty: Bool {
        popularOnTvQ.isEmpty && trending.isEmpty && airingToday.isEmpty
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            async let trendingResult = try? showRepository.trendingShows()
            async let airingTodayResult = try? showRepository.airingTodayShows()
            async let popularResult = popularShows()
            async let betaResult = isBeta()

            let (trending, airingToday, popular, isBeta) =
                await (trendingResult, airingTodayResult, popularResult, betaResult)
            if Task.isCancelled { return }

            self.trending = trending ?? []
            self.airingToday = airingToday ?? []
            self.popularOnTvQ = popular
            self.showsTvQInvite = isBeta && popular.isEmpty

            if trending == nil, airingToday == nil, popular.isEmpty {
                errorMessage = String(localized: "Couldn't load shows to discover. Check your connection and try again.")
            }
        }
    }

    /// Séries les plus suivies sur tvQ, dans l'ordre du classement. Vide sous le
    /// seuil (AppRules.Recommendations) ou si trends/current est illisible : la
    /// rangée n'apparaît alors tout simplement pas.
    private func popularShows() async -> [ShowSummary] {
        guard let trends = try? await loadTrends(),
              trends.userCount >= AppRules.Recommendations.tvQPopularMinUsers
        else { return [] }

        let eligible = trends.mostFollowed
            .filter { $0.followers >= AppRules.Recommendations.tvQPopularMinFollowers }
        guard eligible.count >= AppRules.Recommendations.tvQPopularMinShows else { return [] }

        let ids = eligible
            .compactMap(\.tmdbID)
            .prefix(AppRules.Recommendations.tvQPopularMaxShows)
        let repository = showRepository

        // Fiches en parallèle (caches à 3 paliers), puis remises dans l'ordre du
        // classement. Une fiche introuvable est simplement omise.
        let resolved: [Int: Show] = await withTaskGroup(of: Show?.self) { group in
            for id in ids {
                group.addTask { try? await repository.getShow(tmdbID: id) }
            }
            var byID: [Int: Show] = [:]
            for await show in group {
                if let show { byID[show.tmdbID] = show }
            }
            return byID
        }
        return ids.compactMap { resolved[$0] }.map { show in
            ShowSummary(tmdbID: show.tmdbID, title: show.title, overview: show.overview, posterURL: show.posterURL)
        }
    }
}
