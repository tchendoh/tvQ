import ActivityKit
import UIKit

/// Mince couche au-dessus d'ActivityKit : programme les Live Activities d'un plan
/// (LiveActivityPlanner) et retire celles qui n'en font plus partie.
///
/// Les activités sont programmées à l'avance (`start:`, iOS 26+) : iOS les fait
/// apparaître 15 min avant le début, même app fermée. Sans serveur, l'app ne
/// peut pas les terminer à heure fixe : elles passent à « Terminé » d'elles-mêmes
/// (staleDate), et l'app les retire à sa prochaine ouverture.
final class LiveActivityScheduler {
    static let shared = LiveActivityScheduler()

    /// Temps pendant lequel « Terminé » reste sur l'écran verrouillé.
    nonisolated static let dismissalDelay: TimeInterval = 15 * 60
    nonisolated static let debugActivityID = "debug-live-activity"

    /// Live Activities permises pour tvQ dans les Réglages d'iOS.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var activities: [Activity<EpisodeActivityAttributes>] {
        Activity<EpisodeActivityAttributes>.activities
    }

    func apply(_ plan: [PlannedLiveActivity], now: Date = .now) async {
        let kept = await Self.endActivities(notIn: Set(plan.map(\.episodeID)), now: now)
        for planned in plan where !kept.contains(planned.episodeID) {
            await request(planned, now: now)
        }
        removeUnusedImages()
    }

    /// Déconnexion, ou Live Activities désactivées dans les réglages de tvQ.
    func endAll() async {
        await Self.endAllActivities()
        removeUnusedImages()
    }

    // MARK: - Outils

    private func request(_ planned: PlannedLiveActivity, now: Date) async {
        let artwork = await ActivityArtwork.prepare(for: planned)
        let attributes = EpisodeActivityAttributes(
            episodeID: planned.episodeID,
            tmdbID: planned.tmdbID,
            showTitle: planned.showTitle,
            network: planned.network,
            episodeCode: planned.episodeCode,
            episodeTitle: planned.episodeTitle,
            airDate: planned.airDate,
            endDate: planned.endDate,
            imageFileName: artwork,
            tint: planned.color.map(DominantColor.readableForWhiteText),
            accentTint: planned.accent
        )
        let content = ActivityContent(state: EpisodeActivityAttributes.ContentState(), staleDate: planned.endDate)
        do {
            if planned.startDate > now {
                // Une alerte est obligatoire pour une activité programmée : c'est
                // elle qui remplace la notification « commence ».
                let alert = AlertConfiguration(
                    title: LocalizedStringResource(stringLiteral: planned.showTitle),
                    body: "\(planned.episodeCode) “\(planned.episodeTitle)” starts in 15 minutes.",
                    sound: .default
                )
                _ = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: alert,
                    start: planned.startDate
                )
            } else {
                // Déjà commencé (app ouverte pendant l'épisode) : tout de suite.
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
        } catch {
            Log.notifications.error("Live Activity refusée pour \(planned.episodeID)", error)
        }
    }

    // Les objets Activity ne sont pas Sendable, et `end` s'exécute hors du MainActor :
    // on les lit et on les termine dans des fonctions nonisolated, sans jamais les
    // faire passer du MainActor à un autre contexte.

    /// Termine les activités absentes du plan (ou déjà finies) ; retourne les
    /// identifiants des épisodes dont l'activité est gardée.
    nonisolated private static func endActivities(notIn wanted: Set<String>, now: Date) async -> Set<String> {
        var kept: Set<String> = []
        for activity in Activity<EpisodeActivityAttributes>.activities {
            let id = activity.attributes.episodeID
            let isLive = activity.activityState == .active || activity.activityState == .pending
            // L'activité de test (page de débogage) ne fait jamais partie du plan :
            // sans cette exception, le prochain calcul la retirerait aussitôt.
            if (wanted.contains(id) || id == debugActivityID), isLive {
                kept.insert(id)
            } else {
                // Épisode terminé : « Terminé » reste encore un peu. Retirée du plan
                // avant la fin (série coupée ou plus suivie) : retrait immédiat.
                // Écrit ici plutôt que dans une fonction à part : passer l'activité
                // en paramètre empêcherait Swift de prouver qu'elle n'est pas partagée.
                let endDate = activity.attributes.endDate
                let dismissal = endDate + dismissalDelay
                let policy: ActivityUIDismissalPolicy = now >= endDate && dismissal > now ? .after(dismissal) : .immediate
                await activity.end(nil, dismissalPolicy: policy)
            }
        }
        return kept
    }

    nonisolated private static func endAllActivities() async {
        for activity in Activity<EpisodeActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func removeUnusedImages() {
        guard let directory = AppGroup.activityImagesURL,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return }
        let used = Set(activities.compactMap(\.attributes.imageFileName))
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    #if DEBUG
    /// Activité de test, démarrée tout de suite (sans démarrage programmé) : compte
    /// à rebours de 30 s, « épisode » d'une minute, puis « Terminé ». Quelques
    /// secondes suffisent pour voir les trois états.
    func scheduleTest(tmdbID: Int, title: String, backdropURL: URL?, color: ShowColor?, accent: ShowColor? = nil) async {
        let now = Date.now
        let air = now + 30
        let planned = PlannedLiveActivity(
            episodeID: Self.debugActivityID,
            coveredEpisodeIDs: [],
            tmdbID: tmdbID,
            showTitle: title,
            network: "tvQ",
            episodeCode: "S01E01",
            episodeTitle: "Test",
            backdropURL: backdropURL,
            color: color,
            accent: accent,
            startDate: now,
            airDate: air,
            endDate: air + 60
        )
        await request(planned, now: now)
    }

    struct DebugInfo: Identifiable {
        let id: String
        let title: String
        let state: String
        let airDate: Date
        let endDate: Date
    }

    var debugInfo: [DebugInfo] {
        activities.map { activity in
            DebugInfo(
                id: activity.id,
                title: "\(activity.attributes.showTitle) \(activity.attributes.episodeCode)",
                state: "\(activity.activityState)",
                airDate: activity.attributes.airDate,
                endDate: activity.attributes.endDate
            )
        }
        .sorted { $0.airDate < $1.airDate }
    }
    #endif
}

/// Prépare l'image de fond d'une activité dans l'App Group : réduite (ActivityKit
/// refuse une image plus grande que la présentation). La couleur, elle, vient
/// déjà de la série (Show.dominantColor).
enum ActivityArtwork {

    /// Largeur en pixels : un peu plus que la largeur de l'écran verrouillé en points.
    static let maxPixelWidth: CGFloat = 600

    /// Nom du fichier écrit dans AppGroup.activityImagesURL, ou nil.
    static func prepare(for planned: PlannedLiveActivity) async -> String? {
        guard let url = planned.backdropURL, let directory = AppGroup.activityImagesURL else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let image: UIImage
        if let cached = await ImageCache.shared.image(for: url) {
            image = cached
        } else {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let downloaded = UIImage(data: data)
            else { return nil }
            image = downloaded
        }

        let resized = resize(image)
        guard let jpeg = resized.jpegData(compressionQuality: 0.75) else { return nil }
        let fileName = "\(planned.tmdbID).jpg"
        do {
            try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            return nil
        }
        return fileName
    }

    private static func resize(_ image: UIImage) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        guard pixelWidth > maxPixelWidth else { return image }
        let ratio = maxPixelWidth / pixelWidth
        let size = CGSize(width: maxPixelWidth, height: (image.size.height * image.scale * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
