import Foundation

/// Durée de validité des données en cache. C'est le seul endroit où ces durées sont
/// définies : les stores et les services Firestore ne font que retourner la donnée
/// avec sa date de synchronisation, et ce sont les repositories qui décident si elle
/// est encore fraîche.
///
/// Une donnée périmée n'est jamais jetée pour autant : le repository la retourne quand
/// même immédiatement et la rafraîchit en arrière-plan (stale-while-revalidate), ce qui
/// évite un écran vide quand le réseau est lent ou absent.
nonisolated struct CachePolicy: Sendable {
    let maxAge: TimeInterval

    /// Copie locale, par appareil (SwiftData).
    static let local = CachePolicy(maxAge: 60 * 60 * 12)

    /// Copie partagée entre tous les utilisateurs (Firestore) : elle absorbe la charge de
    /// TMDB/TVmaze, donc une fraîcheur de 24 h suffit pour un horaire de diffusion.
    static let shared = CachePolicy(maxAge: 60 * 60 * 24)

    /// Disponibilité de visionnement : les diffuseurs d'une série changent rarement.
    static let watchAvailability = CachePolicy(maxAge: 60 * 60 * 72)

    /// `isEnded`: une série terminée ne change plus jamais (ni statut, ni épisodes),
    /// donc sa copie en cache ne périme pas.
    func isFresh(syncedAt: Date, isEnded: Bool = false, now: Date = .now) -> Bool {
        isEnded || now.timeIntervalSince(syncedAt) < maxAge
    }
}
