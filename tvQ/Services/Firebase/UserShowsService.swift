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
}
