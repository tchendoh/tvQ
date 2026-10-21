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
        /// Sur une image (fiche) : même pastille que FollowBadge.
        case badge
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
            Button {
                followedShowsStore.toggleNotifications(showID: showID)
            } label: {
                switch style {
                case .plain:
                    icon
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                case .badge:
                    icon
                        // Suit Dynamic Type, contrairement à l'ancienne taille fixe de 16 pt.
                        .font(.callout.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().strokeBorder(Color.emphasis.opacity(0.5), lineWidth: 1) }
                        // Comme FollowBadge : lisible sur n'importe quelle image.
                        .environment(\.colorScheme, .dark)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isMuted)
            .accessibilityLabel(isMuted ? Text("Episode alerts off") : Text("Episode alerts on"))
            .accessibilityHint(Text("Turns new-episode alerts for this show on or off."))
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
