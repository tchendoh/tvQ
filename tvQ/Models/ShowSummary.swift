import Foundation

/// Résultat léger de recherche TMDB — pas assez d'information pour résoudre
/// l'IMDB ID pivot (TMDB ne le retourne pas dans /search/tv), donc pas encore
/// un `Show` complet. Sert à afficher une liste de résultats avant que
/// l'utilisateur en sélectionne un, ce qui déclenche la résolution complète.
struct ShowSummary: Identifiable, Equatable, Hashable {
    let tmdbID: Int
    var id: Int { tmdbID }

    let title: String
    let overview: String
    let posterURL: URL?
}
