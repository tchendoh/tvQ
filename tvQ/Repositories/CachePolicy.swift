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
    /// Durée pour une série terminée : plus longue, mais pas infinie (une série
    /// peut revenir). Voir AppRules.Cache.endedShowMaxAge.
    var endedMaxAge: TimeInterval = AppRules.Cache.endedShowMaxAge

    // Durées : voir AppRules.Cache.

    /// Copie locale, par appareil (SwiftData).
    static let local = CachePolicy(maxAge: AppRules.Cache.localMaxAge)

    /// Copie partagée entre tous les utilisateurs (Firestore).
    static let shared = CachePolicy(maxAge: AppRules.Cache.sharedMaxAge)

    /// Disponibilité de visionnement (« Où regarder »).
    static let watchAvailability = CachePolicy(maxAge: AppRules.Cache.watchAvailabilityMaxAge)

    /// `isEnded` : une série terminée change rarement, sa copie dure donc plus
    /// longtemps (endedMaxAge), sans être éternelle : une série peut être relancée.
    func isFresh(syncedAt: Date, isEnded: Bool = false, now: Date = .now) -> Bool {
        now.timeIntervalSince(syncedAt) < (isEnded ? max(maxAge, endedMaxAge) : maxAge)
    }
}
