import SwiftUI

/// Cloche d'une série : coupe ou réactive ses alertes de nouveaux épisodes,
/// notifications et Live Activities ensemble. Visible dès que l'une des deux est
/// active (réglage activé et permis par iOS) ; invisible sinon, puisqu'elle
/// n'aurait aucun effet.
///
/// La permission des Live Activities n'est pas observée : si elle change dans
/// les Réglages d'iOS pendant que l'app est ouverte, la cloche suit au prochain
/// rafraîchissement de la vue.
struct NotificationBell: View {
    enum Style {
        /// Dans une liste (Schedule).
        case plain
        /// Sur une image : ToggleBadgeLabel, comme FollowBadge.
        case badge
        /// En-tête de la fiche, à côté du grand bouton de suivi
        /// (ShowDetailActions) : bouton de verre rond de même hauteur.
        case glass
    }

    let showID: String
    var style: Style = .plain

    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @AppStorage(AppSettings.Keys.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(AppSettings.Keys.liveActivitiesEnabled) private var liveActivitiesEnabled = true
    private let scheduler = NotificationScheduler.shared
    private let liveActivityScheduler = LiveActivityScheduler.shared

    private var isMuted: Bool { followedShowsStore.areNotificationsMuted(showID) }

    private var hasActiveAlerts: Bool {
        (notificationsEnabled && scheduler.isAuthorized)
            || (liveActivitiesEnabled && liveActivityScheduler.areActivitiesEnabled)
    }

    var body: some View {
        if hasActiveAlerts, followedShowsStore.isFollowing(showID) {
            if style == .glass {
                Button {
                    followedShowsStore.toggleNotifications(showID: showID)
                } label: {
                    Image(systemName: isMuted ? "bell.slash" : "bell")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.headline)
                        .foregroundStyle(isMuted ? .secondary : .primary)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .sensoryFeedback(.impact(weight: .light), trigger: isMuted)
                .modifier(BellAccessibility(isMuted: isMuted))
            } else {
                Button {
                    followedShowsStore.toggleNotifications(showID: showID)
                } label: {
                    switch style {
                    case .badge:
                        // Même pastille que FollowBadge.
                        ToggleBadgeLabel(
                            systemImage: isMuted ? "bell.slash" : "bell",
                            isOn: !isMuted,
                            offColor: .secondary
                        )
                    default:
                        icon
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            // La pastille (ToggleBadgeLabel) a son propre retour haptique.
                            .sensoryFeedback(.impact(weight: .light), trigger: isMuted)
                    }
                }
                .buttonStyle(.plain)
                .modifier(BellAccessibility(isMuted: isMuted))
            }
        }
    }

    /// Contour dans les deux états, plus léger qu'une cloche pleine. L'état se lit à
    /// la forme (barre oblique) autant qu'à la teinte : activée en gris foncé, coupée
    /// en gris pâle. C'est l'exception, la série coupée, qui s'efface.
    private var icon: some View {
        Image(systemName: isMuted ? "bell.slash" : "bell")
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(isMuted ? .tertiary : .secondary)
    }
}

private struct BellAccessibility: ViewModifier {
    let isMuted: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(isMuted ? Text("Episode alerts off") : Text("Episode alerts on"))
            .accessibilityHint(Text("Turns new-episode alerts for this show on or off."))
    }
}
