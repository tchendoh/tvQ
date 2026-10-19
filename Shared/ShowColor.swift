import Foundation

/// Couleur dominante d'une série, tirée de son image (aucune de nos API n'en
/// fournit). Composantes 0...1, sans dépendre de SwiftUI ni d'UIKit, pour être
/// stockée avec la série (SwiftData, Firestore) et passée à la Live Activity.
nonisolated struct ShowColor: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}
