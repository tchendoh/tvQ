import UIKit
import CryptoKit

/// Cache d'images à deux paliers pour les posters (TMDB) — mémoire (NSCache,
/// instantané) puis disque (survit aux redémarrages). Contrairement aux
/// caches de métadonnées (LocalShowCache, etc.), pas de TTL : une image de
/// poster ne change essentiellement jamais une fois publiée.
actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    private let directoryURL: URL

    init(directoryURL: URL = ImageCache.defaultDirectoryURL) {
        self.directoryURL = directoryURL
    }

    private static var defaultDirectoryURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tvQ", isDirectory: true)
            .appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for key: String) -> URL {
        directoryURL.appendingPathComponent(key.sha256Hex)
    }

    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        let fileURL = fileURL(for: url.absoluteString)
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else {
            return nil
        }
        memoryCache.setObject(image, forKey: key)
        return image
    }

    func store(_ image: UIImage, data: Data, for url: URL) {
        memoryCache.setObject(image, forKey: url.absoluteString as NSString)
        try? data.write(to: fileURL(for: url.absoluteString), options: .atomic)
    }

    /// Vide ce palier — utilisé par le bouton "Clear local cache" de Settings.
    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: directoryURL)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}

private extension String {
    /// Hash stable entre les lancements (contrairement à Hasher, qui varie
    /// d'un processus à l'autre) — nécessaire puisque ça sert de nom de
    /// fichier sur disque.
    var sha256Hex: String {
        let digest = SHA256.hash(data: Data(self.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
