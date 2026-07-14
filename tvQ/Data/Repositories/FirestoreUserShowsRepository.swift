import Foundation
import FirebaseFirestore

/// Implémentation concrète de UserShowsRepository : Firestore, une sous-collection
/// par utilisateur (users/{userID}/followedShows/{showID}). C'est le seul endroit
/// de l'app qui importe FirebaseFirestore — le reste ne voit que le protocole.
final class FirestoreUserShowsRepository: UserShowsRepository {
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
