import Foundation
import Observation

/// Pilote l'écran de recherche de séries. Ne connaît que ShowRepository —
/// aucune référence à TMDB, TVmaze ou URLSession ici.
@Observable
final class SearchViewModel {
    private(set) var results: [ShowSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var query: String = ""

    private let showRepository: ShowRepository
    private var searchTask: Task<Void, Never>?

    init(showRepository: ShowRepository = ShowRepository()) {
        self.showRepository = showRepository
    }

    /// Appelée quand l'alerte d'erreur est fermée — sans ça, errorMessage reste non-nil
    /// et l'alerte se re-déclenche en boucle (voire plante) à la prochaine erreur identique.
    func dismissError() {
        errorMessage = nil
    }

    /// Appelée depuis la vue (par ex. via .onChange(of: query) ou .onSubmit).
    /// Annule une recherche en cours si l'utilisateur retape avant qu'elle finisse.
    func search() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        searchTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let searchResults = try await showRepository.search(query: trimmedQuery)
                if !Task.isCancelled {
                    results = searchResults
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = String(localized: "Search failed. Check your connection and try again.")
                }
            }
        }
    }
}
