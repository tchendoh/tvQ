import Foundation
import FirebaseFirestore

/// Accès Firestore à la liste des séries suivies. C'est le seul endroit de l'app
/// qui connaît cette structure : le reste passe par ce service.
///
/// Structure : un seul document par utilisateur, avec un dictionnaire
/// showID → date d'ajout :
///
///     users/{userID} → { followedShows: { "1399": <Timestamp>, ... },
///                        mutedShows: { "1399": true, ... } }
///
/// mutedShows : séries suivies dont les notifications sont coupées (cloche).
///
/// Une seule lecture pour obtenir toute la liste, peu importe le nombre de séries
/// (Firestore facture par document lu). La date d'ajout n'est pas encore affichée,
/// mais elle est gardée parce qu'elle serait impossible à reconstituer plus tard
/// (tri par date d'ajout, « suivie depuis »...).
final class UserShowsService {
    nonisolated private static let field = "followedShows"
    nonisolated private static let mutedField = "mutedShows"

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func userDocument(userID: String) -> DocumentReference {
        db.collection("users").document(userID)
    }

    nonisolated struct FollowedShows: Sendable {
        let followedIDs: [String]
        let mutedIDs: [String]
    }

    /// Séries suivies et cloches coupées, au fil des changements. Le premier
    /// envoi vient de la copie locale de Firestore quand elle existe (affichage
    /// immédiat, même hors ligne), puis du serveur ; ensuite, chaque changement,
    /// y compris ceux faits depuis un autre appareil. Firestore facture une
    /// lecture au démarrage de l'écoute, puis une par changement venu du serveur.
    /// Terminer l'itération (ou annuler sa tâche) retire l'écouteur.
    func followedShowsUpdates(userID: String) -> AsyncThrowingStream<FollowedShows, Error> {
        AsyncThrowingStream { continuation in
            // ListenerRegistration n'est pas Sendable, mais remove() peut être appelé
            // de n'importe quel fil : Firestore le documente comme sûr.
            nonisolated(unsafe) let registration = userDocument(userID: userID).addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.yield(Self.followedShows(from: snapshot?.data() ?? [:]))
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    nonisolated private static func followedShows(from data: [String: Any]) -> FollowedShows {
        let followed = data[field] as? [String: Any] ?? [:]
        let muted = (data[mutedField] as? [String: Any] ?? [:]).keys
        return FollowedShows(followedIDs: Array(followed.keys), mutedIDs: Array(muted))
    }

    func setNotificationsMuted(_ muted: Bool, showID: String, userID: String) async throws {
        try await userDocument(userID: userID).setData(
            // Annotation explicite : les deux branches n'ont pas le même type.
            [Self.mutedField: [showID: muted ? true as Any : FieldValue.delete()]],
            merge: true
        )
    }

    func follow(showID: String, userID: String) async throws {
        // merge : n'ajoute que cette clé au dictionnaire, sans toucher aux autres.
        try await userDocument(userID: userID).setData(
            [Self.field: [showID: FieldValue.serverTimestamp()]],
            merge: true
        )
    }

    func unfollow(showID: String, userID: String) async throws {
        try await userDocument(userID: userID).setData(
            [Self.field: [showID: FieldValue.delete()]],
            merge: true
        )
    }

    /// Plusieurs séries d'un coup, en une seule écriture (bouton « Unfollow all » des
    /// séries terminées). Retire aussi leurs cloches coupées, devenues inutiles.
    func unfollow(showIDs: Set<String>, userID: String) async throws {
        guard !showIDs.isEmpty else { return }
        let deletions = Dictionary(uniqueKeysWithValues: showIDs.map { ($0, FieldValue.delete()) })
        try await userDocument(userID: userID).setData(
            [Self.field: deletions, Self.mutedField: deletions],
            merge: true
        )
    }

    /// Supprime toutes les données Firestore de l'utilisateur (suppression de compte) :
    /// tout tient dans un seul document. À appeler *avant* de supprimer le compte Auth,
    /// tant que les règles de sécurité voient encore l'utilisateur comme authentifié.
    func deleteAllData(userID: String) async throws {
        try await userDocument(userID: userID).delete()
    }
}
