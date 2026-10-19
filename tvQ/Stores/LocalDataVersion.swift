import Foundation
import Observation

/// Compteur qui augmente à chaque changement réel de la base locale (SwiftData).
/// Les stores l'incrémentent après une écriture ; les écrans qui affichent des données
/// locales l'observent avec `.task(id: LocalDataVersion.shared.value)` et se relisent.
///
/// C'est le pont entre la base et l'interface : `@Observable` ne voit que la mémoire,
/// et les view models gardent des copies (`Episode`, `Show` sont des structs). Grâce à
/// lui, un rafraîchissement en arrière-plan apparaît à l'écran sans rien recharger.
@Observable
final class LocalDataVersion {
    static let shared = LocalDataVersion()

    private(set) var value = 0

    func bump() {
        value &+= 1
    }

    /// Depuis un store (actor) : l'incrément se fait sur le MainActor, sans attendre.
    nonisolated static func bumpFromStore() {
        Task { @MainActor in shared.bump() }
    }
}
