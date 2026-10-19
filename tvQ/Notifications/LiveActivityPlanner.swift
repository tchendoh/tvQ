import Foundation

/// Une Live Activity à programmer, décrite sans rien d'ActivityKit.
nonisolated struct PlannedLiveActivity: Equatable, Sendable {
    let episodeID: String
    /// Épisodes couverts par l'activité (plusieurs si une saison sort d'un coup à
    /// heure fixe) : leurs notifications « commence » sont retirées.
    let coveredEpisodeIDs: [String]
    let tmdbID: Int
    let showTitle: String
    let network: String?
    let episodeCode: String
    let episodeTitle: String
    let backdropURL: URL?
    /// Couleur de la série (Show.dominantColor), telle quelle.
    let color: ShowColor?
    /// Couleur d'accent (Show.accentColor), déjà lisible sur fond sombre.
    var accent: ShowColor? = nil
    /// Apparition sur l'écran verrouillé (15 min avant le début).
    let startDate: Date
    let airDate: Date
    let endDate: Date
}

/// Décide quelles Live Activities programmer : les épisodes à heure exacte
/// (TVmaze), diffusés en soirée, dans les prochaines 24 h. Pur et sans effet de
/// bord, comme NotificationPlanner (tests : LiveActivityPlannerTests).
nonisolated struct LiveActivityPlanner: Sendable {
    /// Apparition avant le début de l'épisode.
    static let leadTime: TimeInterval = 15 * 60
    /// iOS limite le nombre d'activités simultanées, programmées comprises : on
    /// ne programme que la journée qui vient, reprogrammée à chaque ouverture.
    static let horizon: TimeInterval = 24 * 3600
    static let maxCount = 3

    /// Minutes depuis minuit : avant cette heure (ou après 23 h), une sortie est
    /// « de nuit » (plateforme à 3 h) et n'a pas de soirée de diffusion à suivre.
    var morningMinutes: Int
    var calendar: Calendar = .current

    func plan(items: [NotificationPlanner.Item], mutedShowIDs: Set<String>, now: Date) -> [PlannedLiveActivity] {
        let typicalRuntimes = NotificationPlanner.typicalRuntimeByShow(items)

        // Une activité par série et par heure de diffusion (saison complète à 20 h).
        var groups: [String: [NotificationPlanner.Item]] = [:]
        for item in items {
            guard !mutedShowIDs.contains(item.show.id),
                  item.episode.hasPreciseTime,
                  let airDate = item.episode.airDate,
                  isEveningBroadcast(airDate)
            else { continue }
            groups["\(item.show.id)-\(Int(airDate.timeIntervalSince1970))", default: []].append(item)
        }

        return groups.values.compactMap { group -> PlannedLiveActivity? in
            let sorted = group.sorted {
                ($0.episode.seasonNumber, $0.episode.episodeNumber) < ($1.episode.seasonNumber, $1.episode.episodeNumber)
            }
            let first = sorted[0]
            guard let airDate = first.episode.airDate else { return nil }
            let runtime = first.episode.runtimeMinutes
                ?? typicalRuntimes[first.show.id]
                ?? NotificationPlanner.defaultRuntimeMinutes
            let endDate = airDate + TimeInterval(runtime * 60)
            let startDate = airDate - Self.leadTime
            // Encore à venir ou en cours, et dans la journée qui vient.
            guard endDate > now, startDate <= now + Self.horizon else { return nil }

            return PlannedLiveActivity(
                episodeID: first.episode.id,
                coveredEpisodeIDs: sorted.map(\.episode.id),
                tmdbID: first.show.tmdbID,
                showTitle: first.show.title,
                network: first.show.network,
                episodeCode: String(format: "S%02dE%02d", first.episode.seasonNumber, first.episode.episodeNumber),
                episodeTitle: first.episode.title,
                backdropURL: first.show.backdropURL,
                color: first.show.dominantColor,
                accent: first.show.accentColor,
                startDate: startDate,
                airDate: airDate,
                endDate: endDate
            )
        }
        .sorted { $0.airDate < $1.airDate }
        .prefix(Self.maxCount)
        .map { $0 }
    }

    /// Diffusion entre l'heure du matin et 23 h, heure locale.
    func isEveningBroadcast(_ airDate: Date) -> Bool {
        let local = calendar.dateComponents([.hour, .minute], from: airDate)
        let minutes = (local.hour ?? 0) * 60 + (local.minute ?? 0)
        return minutes >= morningMinutes && minutes < NotificationPlanner.nightStartMinutes
    }
}
