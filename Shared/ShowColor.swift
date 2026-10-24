import Foundation

/// Couleur dominante d'une série, tirée de son image (aucune de nos API n'en
/// fournit). Composantes 0...1, sans dépendre de SwiftUI ni d'UIKit, pour être
/// stockée avec la série (SwiftData, Firestore) et passée à la Live Activity.
nonisolated struct ShowColor: Codable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

nonisolated extension ShowColor {
    /// Couleur d'accent d'une série, seul calcul utilisé partout (fiche, Live
    /// Activity) : la deuxième couleur de l'image si elle en a une, sinon la
    /// dominante éclaircie. nil seulement sans aucune couleur.
    ///
    /// Une image d'une seule famille de teintes n'a pas d'accent (voir
    /// DominantColor.palette) : on en dérive un pour avoir toujours deux couleurs.
    static func resolvedAccent(accent: ShowColor?, dominant: ShowColor?) -> ShowColor? {
        if let accent { return accent }
        return dominant?.brightened
    }

    /// La même teinte, poussée jusqu'à ce que sa composante la plus forte
    /// atteigne 1 (au plus ×4) : lisible sur fond sombre.
    var brightened: ShowColor {
        let brightest = max(red, green, blue, 0.01)
        let boost = min(1 / brightest, 4)
        return ShowColor(red: min(red * boost, 1), green: min(green * boost, 1), blue: min(blue * boost, 1))
    }
}
