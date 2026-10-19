import Foundation
import Observation

/// Résout les Show complets à partir des IDs suivis (FollowedShowsStore), et lit
/// en local l'épisode le plus proche de chaque série (tri et affichage en liste).
/// Aucune référence à Firestore ici.
@Observable
final class MyShowsViewModel {
    private(set) var shows: [Show] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Épisode le plus proche d'aujourd'hui pour chaque série (sorti dans les 7
    /// derniers jours ou à venir), par showID. Lu dans la base locale seulement :
    /// l'horaire (Schedule) se charge de la tenir à jour.
    private(set) var nearestEpisodes: [String: Episode] = [:]

    enum SortOrder: String {
        /// Séries dont un épisode vient de sortir ou sort bientôt d'abord.
        case recent
        case title
    }

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

    /// Les séries sont déjà triées par titre ; le tri « récent » met devant celles
    /// qui ont un épisode proche, de la plus proche à la moins proche.
    func sorted(_ shows: [Show], by order: SortOrder, now: Date = .now) -> [Show] {
        guard order == .recent else { return shows }
        func distance(_ show: Show) -> TimeInterval {
            guard let date = nearestEpisodes[show.id]?.airDate else { return .infinity }
            return abs(date.timeIntervalSince(now))
        }
        // Tri stable : à distance égale (ou sans épisode), l'ordre par titre reste.
        return shows.enumerated()
            .sorted { (distance($0.element), $0.offset) < (distance($1.element), $1.offset) }
            .map(\.element)
    }

    /// Relit en local l'épisode le plus proche de chaque série. Sans réseau : appelé
    /// au chargement et à chaque changement de la base locale (LocalDataVersion).
    func refreshNearestEpisodes() async {
        let candidates = shows.filter { $0.status != .ended }
        guard let episodes = try? await scheduleRepository.localUpcomingEpisodes(for: candidates) else { return }
        nearestEpisodes = Self.nearest(in: episodes, now: .now)
    }

    static func nearest(in episodes: [Episode], now: Date) -> [String: Episode] {
        var result: [String: Episode] = [:]
        for episode in episodes {
            guard let date = episode.airDate else { continue }
            if let current = result[episode.showID]?.airDate,
               abs(current.timeIntervalSince(now)) <= abs(date.timeIntervalSince(now)) {
                continue
            }
            result[episode.showID] = episode
        }
        return result
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

        guard !missingIDs.isEmpty else {
            Task { await refreshNearestEpisodes() }
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
                shows = ((reloadAll ? [] : shows) + resolved).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                await refreshNearestEpisodes()
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your shows. Check your connection and try again.")
                }
            }
        }
    }
}
