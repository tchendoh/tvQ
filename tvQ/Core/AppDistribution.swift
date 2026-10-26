import StoreKit

/// Canal par lequel tvQ a été installé. Sert à montrer certains éléments seulement
/// aux testeurs (ex. la carte d'invitation « Popular on tvQ » de Home), jamais dans
/// la version App Store : Apple refuse le contenu temporaire (Guideline 2.1).
enum AppDistribution {
    /// Vrai pour TestFlight (environnement sandbox) et pour les builds lancés depuis
    /// Xcode ; faux pour l'App Store, ou si iOS ne peut pas répondre.
    static func isBeta() async -> Bool {
        #if DEBUG
        return true
        #else
        guard case .verified(let transaction) = try? await AppTransaction.shared else { return false }
        return transaction.environment == .sandbox || transaction.environment == .xcode
        #endif
    }
}
