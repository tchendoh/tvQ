import Foundation

/// Conteneur partagé entre l'app et l'extension tvQActivity (capability App Groups,
/// même identifiant dans les deux cibles). Sert aux images des Live Activities :
/// l'extension n'a pas accès au réseau.
nonisolated enum AppGroup {
    static let identifier = "group.com.ericchandonnet.tvQ"

    /// nil si l'App Group n'est pas configuré pour la cible (l'activité s'affiche
    /// alors sans image).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var activityImagesURL: URL? {
        containerURL?.appendingPathComponent("ActivityImages", isDirectory: true)
    }
}
