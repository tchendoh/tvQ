import Foundation
import FirebaseFirestore
import FirebaseCrashlytics

/// Dépassement de quota Firestore (forfait Spark : 50 000 lectures et 20 000
/// écritures par jour, remise à zéro à minuit heure du Pacifique). Au-delà, toutes
/// les requêtes échouent avec resourceExhausted, pour tous les utilisateurs.
///
/// Volontairement, on n'annonce pas d'heure de retour : le même code d'erreur sert
/// aussi aux limites de débit, qui se résorbent en quelques secondes.
enum FirestoreQuota {
    /// Une seule remontée Crashlytics par lancement : assez pour être averti, sans
    /// noyer le tableau de bord quand chaque requête échoue.
    private static var hasRecorded = false

    static func isExceeded(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain
            && nsError.code == FirestoreErrorCode.resourceExhausted.rawValue
    }

    /// Envoie l'erreur à Crashlytics comme erreur non fatale si c'est un dépassement
    /// de quota. Sans effet pour les autres erreurs.
    static func recordIfExceeded(_ error: Error) {
        guard isExceeded(error), !hasRecorded else { return }
        hasRecorded = true
        Crashlytics.crashlytics().record(error: error, userInfo: ["reason": "firestore-quota"])
    }

    /// Message à afficher : celui du quota s'il s'applique, sinon `fallback`.
    /// Remonte aussi l'erreur à Crashlytics au besoin.
    static func message(for error: Error, fallback: String) -> String {
        recordIfExceeded(error)
        return isExceeded(error)
            ? String(localized: "tvQ is temporarily over capacity. Try again in a few hours. Your shows are still available.")
            : fallback
    }
}
