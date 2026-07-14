import Foundation
import Observation

/// Résout les Show complets à partir des IDs suivis (FollowedShowsStore).
/// Ne connaît que ShowRepository — aucune référence à Firestore ici.
@Observable
final class MyShowsViewModel {
    private(set) var shows: [Show] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let showRepository: ShowRepository
    private var loadTask: Task<Void, Never>?

    init(showRepository: ShowRepository = RemoteShowRepository()) {
        self.showRepository = showRepository
    }

    /// Appelée depuis .task(id: followedShowsStore.followedShowIDs) — se relance
    /// automatiquement à chaque follow/unfollow.
    func load(showIDs: Set<String>) {
        loadTask?.cancel()

        guard !showIDs.isEmpty else {
            shows = []
            errorMessage = nil
            return
        }

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                var resolved: [Show] = []
                for idString in showIDs {
                    guard let tmdbID = Int(idString) else { continue }
                    let show = try await showRepository.getShow(tmdbID: tmdbID)
                    if Task.isCancelled { return }
                    resolved.append(show)
                }
                shows = resolved.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Couldn't load your shows. Check your connection and try again.")
                }
            }
        }
    }
}
