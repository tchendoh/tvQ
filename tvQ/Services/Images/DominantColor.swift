import UIKit

/// Couleur dominante d'une image (aucune de nos API ne fournit de couleurs). Même
/// principe que les lecteurs de musique qui se colorent selon la pochette :
/// vignette, regroupement par teinte, groupe le plus important, en écartant les
/// gris, les noirs et les blancs. Calcul pur, testé dans DominantColorTests ;
/// ShowColorExtractor s'occupe de l'image.
nonisolated enum DominantColor {
    typealias RGB = ShowColor

    static let thumbnailSize = 24
    static let hueBuckets = 12

    static func of(_ image: UIImage) -> RGB? {
        palette(of: image)?.dominant
    }

    /// Couleur dominante et couleur d'accent, comme Apple Music avec ses pochettes.
    static func palette(of image: UIImage) -> ShowPalette? {
        guard let pixels = pixels(of: image) else { return nil }
        return palette(in: pixels)
    }

    /// Pixels d'une vignette de l'image, en composantes 0...1.
    static func pixels(of image: UIImage) -> [RGB]? {
        guard let cgImage = image.cgImage else { return nil }
        let size = thumbnailSize
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return nil }
        return stride(from: 0, to: bytes.count, by: 4).map { i in
            RGB(red: Double(bytes[i]) / 255, green: Double(bytes[i + 1]) / 255, blue: Double(bytes[i + 2]) / 255)
        }
    }

    /// Moyenne du groupe de teintes le plus peuplé ; moyenne de tous les pixels
    /// si l'image est presque sans couleur (noir et blanc, gris).
    static func dominant(in pixels: [RGB]) -> RGB? {
        palette(in: pixels)?.dominant
    }

    // Seuils : voir AppRules.Colors.
    static let minShare = AppRules.Colors.minShare
    static let minAccentHueDistance = AppRules.Colors.minAccentHueDistance

    /// Dominante : le groupe de teintes le plus peuplé. Accent : le groupe suivant le
    /// plus peuplé, s'il est assez présent et assez différent, rendu lisible sur fond
    /// sombre. nil pour l'accent si l'image n'a qu'une couleur (la Live Activity
    /// dérive alors l'accent de la dominante).
    static func palette(in pixels: [RGB]) -> ShowPalette? {
        guard !pixels.isEmpty else { return nil }
        let buckets = hueBuckets(of: pixels)
        let ranked = buckets.indices.sorted { buckets[$0].count > buckets[$1].count }
        let isPresent = { (index: Int) in buckets[index].count * minShare >= pixels.count }

        // Moins de 5 % de pixels colorés : on garde la moyenne générale, sans accent.
        guard let first = ranked.first, isPresent(first), let dominant = average(buckets[first]) else {
            return average(pixels).map { ShowPalette(dominant: $0, accent: nil) }
        }

        let accentIndex = ranked.dropFirst().first { index in
            isPresent(index) && hueDistance(first, index) >= minAccentHueDistance
        }
        let accent = accentIndex
            .flatMap { average(buckets[$0]) }
            .map { readableOnDark($0, background: readableForWhiteText(dominant)) }
        return ShowPalette(dominant: dominant, accent: accent)
    }

    /// Distance entre deux groupes de teintes sur la roue (le rouge touche le magenta).
    private static func hueDistance(_ a: Int, _ b: Int) -> Int {
        let difference = abs(a - b)
        return min(difference, hueBuckets - difference)
    }

    /// Pixels colorés répartis par teinte ; les gris, noirs et blancs sont écartés.
    private static func hueBuckets(of pixels: [RGB]) -> [[RGB]] {
        var buckets = [[RGB]](repeating: [], count: hueBuckets)
        for pixel in pixels {
            let maxComponent = max(pixel.red, pixel.green, pixel.blue)
            let minComponent = min(pixel.red, pixel.green, pixel.blue)
            let saturation = maxComponent == 0 ? 0 : (maxComponent - minComponent) / maxComponent
            guard saturation > 0.25, maxComponent > 0.15, maxComponent < 0.97 else { continue }
            let index = min(hueBuckets - 1, Int(hue(of: pixel) * Double(hueBuckets)))
            buckets[index].append(pixel)
        }
        return buckets
    }

    /// Voir AppRules.Colors.
    static let minAccentContrast = AppRules.Colors.minAccentContrast

    /// Pousse la couleur à sa pleine intensité (même teinte), puis l'éclaircit vers
    /// le blanc jusqu'à ce qu'elle ressorte sur le fond.
    static func readableOnDark(_ color: RGB, background: RGB) -> RGB {
        let brightest = max(color.red, color.green, color.blue, 0.01)
        var current = RGB(
            red: min(color.red / brightest, 1),
            green: min(color.green / brightest, 1),
            blue: min(color.blue / brightest, 1)
        )
        for _ in 0..<10 where contrast(current, background) < minAccentContrast {
            current = RGB(
                red: current.red + (1 - current.red) * 0.2,
                green: current.green + (1 - current.green) * 0.2,
                blue: current.blue + (1 - current.blue) * 0.2
            )
        }
        return current
    }

    /// Rapport de contraste WCAG, de 1 (identiques) à 21 (noir sur blanc).
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (la, lb) = (luminance(of: a), luminance(of: b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Assombrit la couleur jusqu'à ce que du texte blanc reste lisible dessus.
    static func readableForWhiteText(_ color: RGB) -> RGB {
        var current = color
        for _ in 0..<12 where luminance(of: current) > maxLuminanceForWhiteText {
            current = RGB(red: current.red * 0.85, green: current.green * 0.85, blue: current.blue * 0.85)
        }
        return current
    }

    /// Au-delà, le contraste avec du blanc passe sous ~4,5:1 (WCAG AA).
    static let maxLuminanceForWhiteText = 0.18

    /// Luminance relative (WCAG), 0 = noir, 1 = blanc.
    static func luminance(of color: RGB) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// Teinte entre 0 et 1 (0 = rouge).
    static func hue(of color: RGB) -> Double {
        let r = color.red, g = color.green, b = color.blue
        let maxComponent = max(r, g, b), minComponent = min(r, g, b)
        let delta = maxComponent - minComponent
        guard delta > 0 else { return 0 }
        var hue: Double
        if maxComponent == r {
            hue = (g - b) / delta
        } else if maxComponent == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        hue /= 6
        return hue < 0 ? hue + 1 : hue
    }

    private static func average(_ pixels: [RGB]) -> RGB? {
        guard !pixels.isEmpty else { return nil }
        let count = Double(pixels.count)
        return RGB(
            red: pixels.map(\.red).reduce(0, +) / count,
            green: pixels.map(\.green).reduce(0, +) / count,
            blue: pixels.map(\.blue).reduce(0, +) / count
        )
    }
}

/// Les deux couleurs d'une série : la dominante (fond) et l'accent (détails).
nonisolated struct ShowPalette: Equatable, Sendable {
    let dominant: ShowColor
    let accent: ShowColor?
}
