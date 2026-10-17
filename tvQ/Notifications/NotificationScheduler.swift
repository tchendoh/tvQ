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
