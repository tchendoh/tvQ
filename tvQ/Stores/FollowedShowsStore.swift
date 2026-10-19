import Foundation
import Observation

/// Source de vérité partagée pour les séries suivies par l'utilisateur courant.
/// Injectée en environment depuis RootView pour que Search, My Shows, etc. restent
/// synchronisés sans refaire un appel réseau à chaque écran.
@Observable
final class FollowedShowsStore {
    private(set) var followedShowIDs: Set<String> = []
    /// Séries suivies dont les notifications sont coupées (cloche).
    private(set) var mutedShowIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let userShowsService: any UserShowsServicing
    private let showRepository: ShowRepository
    private let scheduleRepository: ScheduleRepository
    private var userID: String?
    /// Appelé après un suivi réussi : propose les notifications (voir
    /// NotificationScheduler.offerAfterFollow). Remplaçable dans les tests.
    private let offerNotifications: () async -> Void

    init(
        userShowsService: any UserShowsServicing = UserShowsService(),
        showRepository: ShowRepository = .shared,
        scheduleRepository: ScheduleRepository = .shared,
        offerNotifications: @escaping () async -> Void = { await NotificationScheduler.shared.offerAfterFollow() }
    ) {
        self.offerNotifications = offerNotifications
        self.userShowsService = userShowsService
        self.showRepository = showRepository
        self.scheduleRepository = scheduleRepository
    }

    func isFollowing(_ showID: String) -> Bool {
        followedShowIDs.contains(showID)
    }

    /// À appeler quand l'utilisateur se connecte (voir RootView, .task(id: user.id)).
    func load(userID: String) {
        self.userID = userID
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let followed = try await userShowsService.followedShows(userID: userID)
                // Déconnexion (ou changement de compte) survenue pendant l'appel :
                // ne pas repeupler le store avec les séries de l'ancien compte.
                guard self.userID == userID else { return }
                followedShowIDs = Set(followed.followedIDs)
                mutedShowIDs = Set(followed.mutedIDs)
            } catch {
                errorMessage = FirestoreQuota.message(
                    for: error,
                    fallback: String(localized: "Couldn't load your followed shows.")
                )
            }
        }
    }

    /// À appeler à la déconnexion ou à la suppression de compte (voir RootView) :
    /// le store vit dans RootView, donc survit à la déconnexion et montrerait
    /// sinon les séries de l'ancien compte au suivant.
    func clear() {
        followedShowIDs = []
        mutedShowIDs = []
        errorMessage = nil
        userID = nil
    }

    func areNotificationsMuted(_ showID: String) -> Bool {
        mutedShowIDs.contains(showID)
    }

    /// Cloche d'une série. Optimiste comme toggle(showID:) : l'UI réagit tout de
    /// suite, on revient en arrière si l'écriture échoue.
    func toggleNotifications(showID: String) {
        guard let userID else { return }
        let wasMuted = areNotificationsMuted(showID)
        if wasMuted {
            mutedShowIDs.remove(showID)
        } else {
            mutedShowIDs.insert(showID)
        }

        Task {
            do {
                try await userShowsService.setNotificationsMuted(!wasMuted, showID: showID, userID: userID)
            } catch {
                Log.data.error("setNotificationsMuted a échoué", error)
                if wasMuted {
                    mutedShowIDs.insert(showID)
                } else {
                    mutedShowIDs.remove(showID)
                }
                errorMessage = FirestoreQuota.message(
                    for: error,
                    fallback: String(localized: "Couldn't update notifications for this show. Try again.")
                )
            }
        }
    }

    /// Appelée quand l'alerte d'erreur est fermée (voir MainTabView).
    func dismissError() {
        errorMessage = nil
    }

    /// Bascule optimiste : l'UI réagit immédiatement (voir ShowCardView), on revert
    /// silencieusement si l'appel réseau échoue.
    func toggle(showID: String) {
        guard let userID else { return }
        let wasFollowing = isFollowing(showID)

        if wasFollowing {
            followedShowIDs.remove(showID)
        } else {
            followedShowIDs.insert(showID)
        }

        Task {
            do {
                if wasFollowing {
                    try await userShowsService.unfollow(showID: showID, userID: userID)
                } else {
                    try await userShowsService.follow(showID: showID, userID: userID)
                    prefetchContent(showID: showID)
                    await offerNotifications()
                }
            } catch {
                if wasFollowing {
                    followedShowIDs.insert(showID)
                } else {
                    followedShowIDs.remove(showID)
                }
                errorMessage = FirestoreQuota.message(
                    for: error,
                    fallback: String(localized: "Couldn't update follow status. Try again.")
                )
            }
        }
    }

    /// Réchauffe les caches (disque + Firestore partagé) dès le follow, plutôt que
    /// d'attendre l'ouverture de Schedule/My Shows/ShowDetailView — c'est ce qui
    /// rendait le premier passage sur Schedule si long (getShow + getEpisodes,
    /// un appel TMDB par saison, pour chaque série sans rien en cache). Ici, une
    /// seule série à la fois et en tâche de fond : best-effort, on ignore les
    /// erreurs silencieusement, le vrai chargement se refera normalement si ça échoue.
    private func prefetchContent(showID: String) {
        guard let tmdbID = Int(showID) else { return }
        Task {
            guard let show = try? await showRepository.getShow(tmdbID: tmdbID) else { return }
            _ = try? await scheduleRepository.getEpisodes(for: show)
        }
    }
}
