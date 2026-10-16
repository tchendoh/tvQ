import SwiftUI

/// Remplacement de AsyncImage(url:content:placeholder:) qui passe par ImageCache
/// (mémoire + disque) avant tout accès réseau, et réessaie automatiquement en cas
/// d'échec.
///
/// AsyncImage n'a aucun cache d'image dédié : il s'appuie sur URLSession.shared,
/// dont le cache HTTP ne sert que si le serveur envoie les bons headers, et ne
/// dispense de toute façon jamais du redécodage de l'image à chaque apparition de
/// la vue. Chaque poster (même déjà vu des dizaines de fois) repart donc de zéro,
/// d'où l'effet de chargement "un par un" dans les grilles. Ici, on vérifie
/// d'abord ImageCache (quasi instantané si présent), et seulement en cas de miss
/// on télécharge puis on écrit dans le cache pour la prochaine fois.
///
/// AsyncImage ne réessaie par ailleurs qu'une fois en interne avant de passer en
/// `.failure`, sans plus jamais retenter tant que la vue n'est pas recréée par
/// SwiftUI. Un simple hoquet réseau suffit donc à laisser le placeholder collé
/// indéfiniment ; on réessaie ici manuellement jusqu'à maxAttempts.
struct RetryingAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    private static var maxAttempts: Int { 3 }
    private static var retryDelay: Duration { .seconds(1.5) }

    @State private var image: UIImage?
    @State private var attempt = 0
    @State private var failed = false
    /// URL de l'image actuellement affichée : sert à repartir de zéro quand
    /// l'URL change alors que la vue reste à l'écran.
    @State private var loadedURL: URL?

    /// Identifiant de la tâche de chargement : l'URL ET la tentative. Avec la
    /// tentative seule, un changement d'URL ne relançait rien et l'ancienne
    /// image restait affichée.
    private struct LoadKey: Equatable {
        let url: URL?
        let attempt: Int
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: LoadKey(url: url, attempt: attempt)) {
            if loadedURL != url {
                image = nil
                loadedURL = url
            }
            guard image == nil else { return }
            await load()
        }
    }

    private func load() async {
        guard let url else { return }
        if let cached = await ImageCache.shared.image(for: url) {
            image = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let downloaded = UIImage(data: data) else {
            guard attempt < Self.maxAttempts else { return }
            try? await Task.sleep(for: Self.retryDelay)
            if !Task.isCancelled { attempt += 1 }
            return
        }
        await ImageCache.shared.store(downloaded, data: data, for: url)
        image = downloaded
    }
}
