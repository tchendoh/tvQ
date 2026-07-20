import SwiftUI

/// Remplacement de AsyncImage(url:content:placeholder:) qui réessaie automatiquement
/// en cas d'échec.
///
/// AsyncImage ne réessaie qu'une fois en interne avant de passer en `.failure` — et
/// une fois là, il n'y a plus aucun réessai tant que la vue n'est pas recréée par
/// SwiftUI (ex. en quittant l'onglet et en y revenant). Un simple hoquet réseau
/// (plusieurs images chargées en même temps dans une grille, timeout ponctuel)
/// suffit donc à laisser le placeholder collé indéfiniment, même si la même image
/// se charge sans problème ailleurs dans l'app.
///
/// Ici, on force la recréation de l'AsyncImage sous-jacent via `.id(attempt)` après
/// un court délai, jusqu'à un nombre maximal de tentatives.
struct RetryingAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    private static var maxAttempts: Int { 3 }
    private static var retryDelay: Duration { .seconds(1.5) }

    @State private var attempt = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
                    .task(id: attempt) {
                        guard attempt < Self.maxAttempts else { return }
                        try? await Task.sleep(for: Self.retryDelay)
                        if !Task.isCancelled { attempt += 1 }
                    }
            case .empty:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        // Changer l'identité de la vue force SwiftUI à recréer l'AsyncImage
        // interne, qui relance alors une nouvelle tentative de chargement.
        .id(attempt)
    }
}
