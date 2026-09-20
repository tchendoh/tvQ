import Foundation

/// Entité métier représentant l'utilisateur authentifié.
/// Ne contient aucune référence à Firebase — le mapping se fait dans la couche Data.
struct AppUser: Identifiable, Equatable, Hashable {
    let id: String
    let email: String
    let displayName: String?
}
