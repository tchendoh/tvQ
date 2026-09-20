import Foundation
import FirebaseFirestore

/// Accès Firestore à la liste des séries suivies : une sous-collection
/// par utilisateur (users/{userID}/followedShows/{showID}). C'est le seul endroit
/// de l'app qui importe FirebaseFirestore — le reste de l'app passe par ce service.
final class UserShowsService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func followedShowsCollection(userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("followedShows")
    }

    func followedShowIDs(userID: String) async throws -> [String] {
        let snapshot = try await followedShowsCollection(userID: userID).getDocuments()
        return snapshot.documents.map(\.documentID)
    }

    func follow(showID: String, userID: String) async throws {
        try await followedShowsCollection(userID: userID).document(showID).setData([
            "followedAt": FieldValue.serverTimestamp()
        ])
    }

    func unfollow(showID: String, userID: String) async throws {
        try await followedShowsCollection(userID: userID).document(showID).delete()
    }

    /// Supprime toutes les données Firestore de l'utilisateur (suppression de compte).
    /// Le SDK client ne peut pas supprimer une sous-collection d'un coup : on la vide
    /// par lots (un WriteBatch accepte au plus 500 opérations), puis on retire le
    /// document parent. À appeler *avant* de supprimer le compte Auth, tant que les
    /// règles de sécurité voient encore l'utilisateur comme authentifié.
    func deleteAllData(userID: String) async throws {
        let collection = followedShowsCollection(userID: userID)
        while true {
            let snapshot = try await collection.limit(to: 400).getDocuments()
            if snapshot.isEmpty { break }
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
        }
        try await db.collection("users").document(userID).delete()
    }
}
