import UIKit

/// Calcule les couleurs d'une série (dominante et accent) à partir de son image.
/// Remplaçable dans les tests de ShowRepository.
protocol ShowColorExtracting {
    func palette(for imageURL: URL) async -> ShowPalette?
}

/// Télécharge l'image (ou la prend dans ImageCache, où elle reste ensuite pour
/// l'affichage) et en tire ses couleurs. Best-effort : nil en cas d'échec.
struct ShowColorExtractor: ShowColorExtracting {
    func palette(for imageURL: URL) async -> ShowPalette? {
        guard let image = await ImageCache.shared.loadImage(from: imageURL) else { return nil }
        return DominantColor.palette(of: image)
    }
}

extension Show {
    /// Image d'où tirer les couleurs : l'affiche, l'identité visuelle de la
    /// série (choix du 2026-10-22 ; avant, l'image de fond). L'image de fond
    /// seulement s'il n'y a pas d'affiche.
    var colorSourceURL: URL? { posterURL ?? backdropURL }
}
