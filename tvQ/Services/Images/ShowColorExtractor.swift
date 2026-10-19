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
        if let cached = await ImageCache.shared.image(for: imageURL) {
            return DominantColor.palette(of: cached)
        }
        guard let (data, response) = try? await URLSession.shared.data(from: imageURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data)
        else { return nil }
        await ImageCache.shared.store(image, data: data, for: imageURL)
        return DominantColor.palette(of: image)
    }
}

extension Show {
    /// Image d'où tirer la couleur : l'image de fond, plus représentative de
    /// l'ambiance de la série que l'affiche (souvent chargée de texte).
    var colorSourceURL: URL? { backdropURL ?? posterURL }
}
