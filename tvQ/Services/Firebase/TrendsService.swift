import Foundation
import FirebaseFirestore

/// Lecture du document unique trends/current (une seule lecture Firestore).
/// Écrit seulement par le script du Mac mini ; les règles interdisent toute
/// écriture depuis l'app.
final class TrendsService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    /// nil si le script n'a encore jamais écrit le document.
    func current() async throws -> Trends? {
        let snapshot: DocumentSnapshot
        do {
            snapshot = try await db.collection("trends").document("current").getDocument()
        } catch {
            FirestoreQuota.recordIfExceeded(error)
            Log.data.error("Lecture trends/current échouée", error)
            throw error
        }
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: Trends.self)
    }
}
