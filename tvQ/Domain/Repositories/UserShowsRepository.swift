import Foundation

/// Gère la liste des séries suivies par un utilisateur.
/// Implémentation concrète dans Data : Firestore.
protocol UserShowsRepository {
    func followedShowIDs(userID: String) async throws -> [String]
    func follow(showID: String, userID: String) async throws
    func unfollow(showID: String, userID: String) async throws
}
