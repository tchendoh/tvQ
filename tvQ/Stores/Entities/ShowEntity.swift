import Foundation
import SwiftData

/// Forme persistée d'un `Show`. Les séries ne sont lues que par clé (jamais filtrées
/// par champ), donc le modèle complet est stocké en JSON dans `payload`, ce qui évite
/// de dupliquer tous ses champs. `isEnded` est en attribut à part parce que c'est la
/// seule information dont la politique de cache a besoin sans décoder le JSON.
@Model
nonisolated final class ShowEntity {
    @Attribute(.unique) var cacheKey: String
    var payload: Data
    var isEnded: Bool
    var syncedAt: Date

    init(cacheKey: String, payload: Data, isEnded: Bool, syncedAt: Date) {
        self.cacheKey = cacheKey
        self.payload = payload
        self.isEnded = isEnded
        self.syncedAt = syncedAt
    }
}
