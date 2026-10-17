import SwiftUI

/// Cloche d'une série : coupe ou réactive ses notifications de nouveaux
/// épisodes. Invisible tant que les notifications sont désactivées dans les
/// réglages (ou refusées par iOS) : elle n'aurait alors aucun effet.
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
    private let scheduler = NotificationScheduler.shared

    private var isMuted: Bool { followedShowsStore.areNotificationsMuted(showID) }

    var body: some View {
        if notificationsEnabled, scheduler.isAuthorized, followedShowsStore.isFollowing(showID) {
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
                        .font(.system(size: 16, weight: .bold))
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
            .accessibilityLabel(isMuted ? Text("Notifications off") : Text("Notifications on"))
            .accessibilityHint(Text("Turns new-episode notifications for this show on or off."))
        }
    }

    private var icon: some View {
        Image(systemName: isMuted ? "bell.slash" : "bell.fill")
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(isMuted ? Color.secondary : Color.emphasis)
    }
}
