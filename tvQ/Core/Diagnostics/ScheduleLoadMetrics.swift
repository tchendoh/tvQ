import Foundation

/// D'où a été servi un Show ou une liste d'Episode — utilisé uniquement pour
/// le diagnostic de performance de l'écran Schedule (voir ScheduleLoadMetrics).
/// Pas de tier `.miss` : par construction, un appel finit toujours par
/// `.remote` s'il n'a été trouvé sur aucun des deux caches.
enum CacheTier {
    case local
    case shared
    case remote
}

/// Résumé du dernier chargement de l'écran Schedule (ScheduleViewModel.load) :
/// combien de temps a pris chaque étape, et d'où vient chaque résultat
/// (cache local / Firestore partagé / API fraîche TMDB-TVmaze).
///
/// Sert uniquement à l'affichage diagnostic dans ScheduleView — n'affecte pas
/// le chargement lui-même. Voir BACKLOG.md (2026-08-09) pour le contexte :
/// le chargement de l'horaire peut être lent, ceci permet de voir en un
/// coup d'œil où passe le temps sans sortir Instruments.
struct ScheduleLoadMetrics: Equatable {
    struct TierBreakdown: Equatable {
        var local = 0
        var shared = 0
        var remote = 0

        var total: Int { local + shared + remote }

        mutating func record(_ tier: CacheTier) {
            switch tier {
            case .local: local += 1
            case .shared: shared += 1
            case .remote: remote += 1
            }
        }
    }

    /// Temps pour résoudre les Show complets à partir des IDs suivis.
    var showsDuration: Duration = .zero
    /// Temps pour récupérer les épisodes (à venir/récents) des Show résolus.
    var episodesDuration: Duration = .zero
    /// showsDuration + episodesDuration + le reste (tri, mapping) — ce que
    /// l'utilisateur perçoit réellement avant l'affichage.
    var totalDuration: Duration = .zero

    var showsByTier = TierBreakdown()
    var episodesByTier = TierBreakdown()
}

extension Duration {
    /// Ex. "1.8s" ou "340ms" — Duration.formatted() n'a pas d'unité "auto"
    /// courte adaptée à un petit résumé diagnostic, d'où ce format maison.
    var diagnosticDescription: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        }
        return String(format: "%.1fs", seconds)
    }
}
