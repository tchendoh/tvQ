import Foundation
import Observation

/// Source de vérité partagée pour les séries suivies par l'utilisateur courant.
/// Injectée en environment depuis RootView pour que Search, My Shows, etc. restent
/// synchronisés sans refaire un appel réseau à chaque écran.
@Observable
final class FollowedShowsStore {
    private(set) var followedShowIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: UserShowsRepository
    private var userID: String?

    init(repository: UserShowsRepository = FirestoreUserShowsRepository()) {
        self.repository = repository
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
                let ids = try await repository.followedShowIDs(userID: userID)
                followedShowIDs = Set(ids)
            } catch {
                errorMessage = String(localized: "Couldn't load your followed shows.")
            }
        }
    }

    func clear() {
        followedShowIDs = []
        userID = nil
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
                    try await repository.unfollow(showID: showID, userID: userID)
                } else {
                    try await repository.follow(showID: showID, userID: userID)
                }
            } catch {
                if wasFollowing {
                    followedShowIDs.insert(showID)
                } else {
                    followedShowIDs.remove(showID)
                }
                errorMessage = String(localized: "Couldn't update follow status. Try again.")
            }
        }
    }
}
