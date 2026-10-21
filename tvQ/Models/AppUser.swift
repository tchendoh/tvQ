import Foundation

/// Entité métier représentant l'utilisateur authentifié.
/// Ne contient aucune référence à Firebase — le mapping se fait dans AuthService.
struct AppUser: Identifiable, Equatable, Hashable {
    let id: String
    let email: String
    let displayName: String?
    /// Session anonyme Firebase : aucun courriel ni Apple rattaché pour l'instant.
    let isAnonymous: Bool
}
