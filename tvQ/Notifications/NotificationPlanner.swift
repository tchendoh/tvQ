import Foundation

/// Moment de la notification (épisodes dont l'heure exacte est connue, via TVmaze) :
/// 10 minutes avant le début, au début, ou 10 minutes après la fin.
nonisolated enum NotificationTiming: String, CaseIterable, Identifiable, Sendable {
    case tenMinutesBefore
    case atAirTime
    case tenMinutesAfterEnd

    var id: Self { self }
}

/// Une notification à programmer, décrite sans rien d'iOS : NotificationScheduler
/// la traduit en UNNotificationRequest.
nonisolated struct PlannedNotification: Equatable, Sendable {
    enum Trigger: Equatable, Sendable {
        /// Instant absolu (heure TVmaze) : même moment partout dans le monde.
        case exact(Date)
        /// Heure locale de l'appareil, sans fuseau (« 9 h là où je suis ») :
        /// année, mois, jour, heure, minute.
        case floating(DateComponents)
    }

    /// Stable d'un calcul à l'autre : reprogrammer remplace au lieu de dupliquer.
    let id: String
    let tmdbID: Int
    let showID: String
    let title: String
    let body: String
    let trigger: Trigger
    /// Date de déclenchement dans le calendrier de l'appareil, pour trier et filtrer.
    let fireDate: Date
}

/// Décide quoi notifier et quand, à partir des épisodes de l'horaire. Pur et
/// sans effet de bord : tout ce qui est délicat (fuseaux, nuit, dates TMDB sans
/// heure, regroupements) vit ici et se teste sans iPhone (NotificationPlannerTests).
nonisolated struct NotificationPlanner: Sendable {
    nonisolated struct Item: Sendable {
        let episode: Episode
        let show: Show
    }

    // Valeurs : voir AppRules.Notifications.
    static let horizon = AppRules.Notifications.horizon
    static let maxCount = AppRules.Notifications.maxCount
    static let nightStartMinutes = AppRules.Notifications.nightStartMinutes

    var timing: NotificationTiming
    /// Minutes depuis minuit (540 = 9 h) : épisodes sans heure connue, et
    /// épisodes qui sortent la nuit (plateformes à minuit heure du Pacifique).
    var morningMinutes: Int
    /// Calendrier de l'appareil (fuseau local). Injecté pour les tests.
    var calendar: Calendar = .current

    /// Durée supposée quand ni l'épisode ni la série ne la donnent (AppRules).
    static let defaultRuntimeMinutes = AppRules.Notifications.defaultRuntimeMinutes

    /// `liveActivityEpisodeIDs` : épisodes déjà annoncés par une Live Activity
    /// (voir LiveActivityPlanner). Leur notification « commence » serait un doublon,
    /// ce qu'Apple déconseille ; celle « après la fin » dit autre chose et reste.
    func plan(
        items: [Item],
        mutedShowIDs: Set<String>,
        now: Date,
        liveActivityEpisodeIDs: Set<String> = []
    ) -> [PlannedNotification] {
        var groups: [String: (first: Slot, items: [Item])] = [:]
        let typicalRuntimes = Self.typicalRuntimeByShow(items)
        let coveredByLiveActivity = timing == .tenMinutesAfterEnd ? [] : liveActivityEpisodeIDs

        for item in items where !coveredByLiveActivity.contains(item.episode.id) {
            let runtime = item.episode.runtimeMinutes
                ?? typicalRuntimes[item.show.id]
                ?? Self.defaultRuntimeMinutes
            guard !mutedShowIDs.contains(item.show.id),
                  let slot = slot(for: item.episode, runtimeMinutes: runtime),
                  slot.fireDate > now,
                  slot.fireDate <= now + Self.horizon
            else { continue }

            // Une saison complète sortie d'un coup (Netflix) : une seule
            // notification par série, saison et moment, pas une par épisode.
            let key = "\(item.show.id)-s\(item.episode.seasonNumber)-\(slot.key)"
            if groups[key] == nil {
                groups[key] = (slot, [item])
            } else {
                groups[key]?.items.append(item)
            }
        }

        return groups
            .map { key, group in notification(id: "tvq-\(key)", slot: group.first, items: group.items) }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(Self.maxCount)
            .map { $0 }
    }

    // MARK: - Calcul du moment

    struct Slot {
        let trigger: PlannedNotification.Trigger
        let fireDate: Date
        /// Pourquoi la notification arrive à ce moment : le message en dépend
        /// (« diffusé hier soir » plutôt que « nouvel épisode aujourd'hui » à 9 h).
        let reason: Reason
        /// Identifie le moment dans l'identifiant de la notification.
        let key: String
    }

    /// Durée médiane connue des épisodes de chaque série : repli pour un épisode
    /// dont la durée n'est pas encore publiée.
    static func typicalRuntimeByShow(_ items: [Item]) -> [String: Int] {
        Dictionary(grouping: items.compactMap { item in
            item.episode.runtimeMinutes.map { (item.show.id, $0) }
        }, by: \.0).mapValues { pairs in
            let sorted = pairs.map(\.1).sorted()
            return sorted[sorted.count / 2]
        }
    }

    private func offset(runtimeMinutes: Int) -> TimeInterval {
        switch timing {
        case .tenMinutesBefore: -10 * 60
        case .atAirTime: 0
        case .tenMinutesAfterEnd: TimeInterval(runtimeMinutes + 10) * 60
        }
    }

    /// Raison du moment choisi. Les trois dernières sont des reports à l'heure du matin.
    enum Reason: Equatable {
        /// Heure exacte connue, notification au moment prévu.
        case onTime
        /// Date seule (TMDB) : on sait seulement que l'épisode sort aujourd'hui.
        case dateOnly
        /// Sorti entre minuit et 6 h (plateformes à minuit heure du Pacifique).
        case releasedOvernight
        /// Sorti entre 6 h et l'heure du matin.
        case releasedEarlyMorning
        /// Commencé en soirée (ou plus tôt dans la journée) et reporté au matin
        /// suivant, faute de pouvoir notifier pendant la nuit.
        case airedLastNight
    }

    /// Minute (depuis minuit) qui sépare « cette nuit » de « ce matin ».
    static let earlyMorningStartMinutes = 6 * 60

    func slot(for episode: Episode, runtimeMinutes: Int = NotificationPlanner.defaultRuntimeMinutes) -> Slot? {
        guard let airDate = episode.airDate else { return nil }

        guard episode.hasPreciseTime else {
            // Date seule de TMDB, lue en UTC (voir EpisodeMapper) : on reprend le
            // jour tel quel. Le convertir en heure locale le ferait reculer à la
            // veille partout en Amérique (minuit UTC = 20 h la veille à Montréal).
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            let day = utc.dateComponents([.year, .month, .day], from: airDate)
            return morningSlot(day: day, reason: .dateOnly)
        }

        // Heure locale du début de l'épisode : décide du message d'un report au matin.
        let start = calendar.dateComponents([.hour, .minute], from: airDate)
        let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let deferredReason: Reason = switch startMinutes {
        case ..<Self.earlyMorningStartMinutes: .releasedOvernight
        case ..<morningMinutes: .releasedEarlyMorning
        default: .airedLastNight
        }

        let fireDate = airDate + offset(runtimeMinutes: runtimeMinutes)
        let local = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let minutes = (local.hour ?? 0) * 60 + (local.minute ?? 0)

        if minutes >= Self.nightStartMinutes {
            // Fin de soirée : reporté au lendemain matin.
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: fireDate) else { return nil }
            return morningSlot(day: calendar.dateComponents([.year, .month, .day], from: nextDay),
                               reason: deferredReason)
        }
        if minutes < morningMinutes {
            // Pendant la nuit (ex. 3 h) : reporté au matin du même jour.
            return morningSlot(day: local, reason: deferredReason)
        }
        return Slot(
            trigger: .exact(fireDate),
            fireDate: fireDate,
            reason: .onTime,
            key: String(Int(fireDate.timeIntervalSince1970))
        )
    }

    private func morningSlot(day: DateComponents, reason: Reason) -> Slot? {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = morningMinutes / 60
        components.minute = morningMinutes % 60
        guard let fireDate = calendar.date(from: components),
              let year = day.year, let month = day.month, let dayNumber = day.day
        else { return nil }
        return Slot(
            trigger: .floating(components),
            fireDate: fireDate,
            reason: reason,
            key: String(format: "%04d%02d%02d", year, month, dayNumber)
        )
    }

    // MARK: - Texte

    private func notification(id: String, slot: Slot, items: [Item]) -> PlannedNotification {
        let sorted = items.sorted { $0.episode.episodeNumber < $1.episode.episodeNumber }
        let show = sorted[0].show
        return PlannedNotification(
            id: id,
            tmdbID: show.tmdbID,
            showID: show.id,
            title: show.title,
            body: body(for: sorted.map(\.episode), reason: slot.reason),
            trigger: slot.trigger,
            fireDate: slot.fireDate
        )
    }

    private func body(for episodes: [Episode], reason: Reason) -> String {
        let first = episodes[0]
        let code = first.code

        if episodes.count > 1 {
            let count = episodes.count
            let season = first.seasonNumber
            return switch reason {
            case .releasedOvernight:
                String(localized: "\(count) new episodes of season \(season) are out since last night.")
            case .releasedEarlyMorning:
                String(localized: "\(count) new episodes of season \(season) are out since this morning.")
            case .airedLastNight:
                String(localized: "\(count) new episodes of season \(season) aired last night.")
            case .onTime, .dateOnly:
                String(localized: "\(count) new episodes of season \(season) are out.")
            }
        }

        switch reason {
        case .dateOnly:
            return String(localized: "New episode today: \(code) “\(first.title)”.")
        case .releasedOvernight:
            return String(localized: "Out since last night: \(code) “\(first.title)”.")
        case .releasedEarlyMorning:
            return String(localized: "Out since this morning: \(code) “\(first.title)”.")
        case .airedLastNight:
            return String(localized: "Aired last night: \(code) “\(first.title)”.")
        case .onTime:
            break
        }
        switch timing {
        case .tenMinutesBefore:
            return String(localized: "\(code) “\(first.title)” starts in 10 minutes.")
        case .atAirTime:
            return String(localized: "\(code) “\(first.title)” starts now.")
        case .tenMinutesAfterEnd:
            return String(localized: "\(code) “\(first.title)” just finished airing.")
        }
    }
}
