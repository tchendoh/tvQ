import Foundation
import Observation
import UserNotifications

/// Mince couche au-dessus de UNUserNotificationCenter : permission, et
/// remplacement des notifications programmées par celles d'un plan
/// (NotificationPlanner). Ne touche qu'aux notifications de tvQ (préfixe "tvq-").
@Observable
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    /// État de la permission iOS, rafraîchi au retour au premier plan : l'utilisateur
    /// peut la retirer dans les Réglages d'iOS à tout moment.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private static let idPrefix = "tvq-"

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Affiche la demande d'iOS la première fois ; ensuite, retourne simplement
    /// l'état (iOS ne redemande jamais une permission refusée).
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        return granted
    }

    /// Remplace toutes les notifications de tvQ par celles du plan. Les
    /// identifiants sont stables, donc une notification inchangée est simplement
    /// reprogrammée à l'identique.
    func apply(_ plan: [PlannedNotification]) async {
        await removeAll()
        for planned in plan {
            let request = UNNotificationRequest(
                identifier: planned.id,
                content: content(for: planned),
                trigger: trigger(for: planned)
            )
            try? await center.add(request)
        }
    }

    /// Premier suivi d'une série : le moment naturel pour proposer les notifications,
    /// plutôt qu'au lancement. Ne demande que si iOS n'a jamais posé la question ;
    /// une réponse positive active aussi le réglage de tvQ.
    func offerAfterFollow() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        if await requestAuthorization() {
            UserDefaults.standard.set(true, forKey: AppSettings.Keys.notificationsEnabled)
        }
    }

    #if DEBUG
    /// Notification de test dans quelques secondes, pour vérifier l'affichage et le
    /// toucher (ouverture de la fiche) sans attendre un vrai soir de diffusion.
    /// Identifiant hors du préfixe "tvq-" : un nouveau plan ne l'efface pas.
    func scheduleTestNotification(tmdbID: Int?, title: String, in seconds: TimeInterval = 10) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Test notification from tvQ (Debug)."
        content.sound = .default
        if let tmdbID {
            content.userInfo = [NotificationRouter.tmdbIDKey: tmdbID]
        }
        let request = UNNotificationRequest(
            identifier: "debug-test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
    }

    /// Une notification en attente, telle qu'iOS la voit.
    struct PendingInfo: Identifiable {
        let id: String
        let title: String
        let body: String
        let fireDate: Date?
        /// true : instant absolu (heure TVmaze) ; false : heure locale flottante (matin).
        let isExact: Bool
        let tmdbID: Int?
    }

    /// Notifications de tvQ en attente (et celle de test), triées par date.
    func pendingInfo() async -> [PendingInfo] {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Self.idPrefix) || $0.identifier == "debug-test" }
            .map { request in
                let fireDate: Date?
                let isExact: Bool
                switch request.trigger {
                case let trigger as UNTimeIntervalNotificationTrigger:
                    fireDate = trigger.nextTriggerDate()
                    isExact = true
                case let trigger as UNCalendarNotificationTrigger:
                    fireDate = trigger.nextTriggerDate()
                    isExact = false
                default:
                    fireDate = nil
                    isExact = false
                }
                return PendingInfo(
                    id: request.identifier,
                    title: request.content.title,
                    body: request.content.body,
                    fireDate: fireDate,
                    isExact: isExact,
                    tmdbID: request.content.userInfo[NotificationRouter.tmdbIDKey] as? Int
                )
            }
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }
    #endif

    func removeAll() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func content(for planned: PlannedNotification) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default
        // iOS regroupe les notifications d'une même série dans le centre de notifications.
        content.threadIdentifier = planned.showID
        content.targetContentIdentifier = planned.showID
        content.userInfo = [NotificationRouter.tmdbIDKey: planned.tmdbID]
        return content
    }

    private func trigger(for planned: PlannedNotification) -> UNNotificationTrigger {
        switch planned.trigger {
        case .exact(let date):
            // Instant absolu : un délai ne dépend d'aucun fuseau.
            UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        case .floating(let components):
            // Sans fuseau : se déclenche à l'heure locale de l'appareil, même en voyage.
            UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
    }
}

/// Toucher une notification ouvre la fiche de la série (voir MainTabView).
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()
    nonisolated static let tmdbIDKey = "tmdbID"

    /// Série à ouvrir ; remis à nil quand la fiche se ferme.
    var tmdbID: Int?
}
