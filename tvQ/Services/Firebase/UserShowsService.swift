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
///
/// Ancienne structure (avant octobre 2026) : une sous-collection
/// users/{userID}/followedShows/{showID} = { followedAt }, un document par série.
/// Elle est migrée automatiquement à la première lecture, puis supprimée.
final class UserShowsService {
    private static let field = "followedShows"
    private static let mutedField = "mutedShows"
    /// Présent (true) une fois l'ancienne structure migrée, ou d'emblée pour un
    /// nouveau compte. Tant qu'il est absent, chaque lecture tente la migration.
    private static let migratedField = "legacyMigrated"

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func userDocument(userID: String) -> DocumentReference {
        db.collection("users").document(userID)
    }

    private func legacyCollection(userID: String) -> CollectionReference {
        userDocument(userID: userID).collection("followedShows")
    }

    struct FollowedShows {
        let followedIDs: [String]
        let mutedIDs: [String]
    }

    func followedShows(userID: String) async throws -> FollowedShows {
        let data = try await userDocument(userID: userID).getDocument().data() ?? [:]
        let followed = data[Self.field] as? [String: Any] ?? [:]
        let muted = (data[Self.mutedField] as? [String: Any] ?? [:]).keys
        if data[Self.migratedField] as? Bool == true {
            return FollowedShows(followedIDs: Array(followed.keys), mutedIDs: Array(muted))
        }
        // Indicateur absent : nouveau compte, ou données encore dans l'ancienne
        // structure (un follow fait avant la migration, hors ligne par exemple,
        // peut déjà avoir créé le champ). migrateLegacy fusionne les deux.
        let ids = try await migrateLegacy(userID: userID, current: followed)
        return FollowedShows(followedIDs: ids, mutedIDs: Array(muted))
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

    /// Supprime toutes les données Firestore de l'utilisateur (suppression de compte).
    /// Vide aussi l'ancienne sous-collection, au cas où la migration n'aurait jamais
    /// eu lieu (compte jamais rouvert depuis le changement de structure). À appeler
    /// *avant* de supprimer le compte Auth, tant que les règles de sécurité voient
    /// encore l'utilisateur comme authentifié.
    func deleteAllData(userID: String) async throws {
        try await deleteLegacyDocuments(userID: userID)
        try await userDocument(userID: userID).delete()
    }

    // MARK: - Migration depuis l'ancienne structure

    /// Recopie l'ancienne sous-collection dans le dictionnaire (en gardant les dates
    /// d'ajout), marque la migration comme faite, puis supprime l'ancienne structure.
    private func migrateLegacy(userID: String, current: [String: Any]) async throws -> [String] {
        let legacy = try await legacyCollection(userID: userID).getDocuments()

        var migrated: [String: Any] = [:]
        for document in legacy.documents where current[document.documentID] == nil {
            migrated[document.documentID] = document.data()["followedAt"] as? Timestamp
                ?? FieldValue.serverTimestamp()
        }

        // merge : n'ajoute que les anciennes séries, sans toucher à celles déjà là.
        try await userDocument(userID: userID).setData(
            [Self.field: migrated, Self.migratedField: true],
            merge: true
        )

        if !legacy.isEmpty {
            // Best-effort : si ça échoue, la migration a quand même réussi et les
            // anciens documents seront retirés à une prochaine suppression de compte.
            try? await deleteLegacyDocuments(userID: userID)
        }
        return Array(Set(current.keys).union(migrated.keys))
    }

    /// Le SDK client ne peut pas supprimer une sous-collection d'un coup : on la vide
    /// par lots (un WriteBatch accepte au plus 500 opérations).
    private func deleteLegacyDocuments(userID: String) async throws {
        let collection = legacyCollection(userID: userID)
        while true {
            let snapshot = try await collection.limit(to: 400).getDocuments()
            if snapshot.isEmpty { break }
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
    }
}
