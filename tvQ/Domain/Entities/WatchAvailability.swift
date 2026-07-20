import Foundation

/// Où regarder une série dans un pays donné (streaming, achat ou location),
/// dérivé de `TMDBWatchProvidersDTO` pour la région choisie par l'utilisateur
/// (voir AppSettings.watchProviderRegion). Texte seulement dans l'UI —
/// pas de logos (jugés pas assez propres visuellement, voir ShowDetailView).
nonisolated struct WatchAvailability: Equatable, Codable {
    /// Nom du pays affiché à l'utilisateur (ex. "Canada"), pas le code ISO brut.
    let regionDisplayName: String

    /// Noms de diffuseurs, dédupliqués — streaming (`flatrate`) d'abord, puis
    /// achat/location, sans distinguer les deux dans l'affichage. Vide si TMDB
    /// n'a aucune donnée pour ce pays (peut arriver même si un lien JustWatch
    /// existe) — dans ce cas l'UI affiche un CTA "Where to watch?" plutôt que
    /// rien, voir ShowDetailView.
    let providerNames: [String]

    /// Lien retourné par TMDB pour cette région (pointe vers themoviedb.org,
    /// qui redirige lui-même vers JustWatch — TMDB ne fournit pas de deep-link
    /// direct, voir WatchAvailabilityMapper), ou repli sur la page d'accueil
    /// JustWatch si TMDB n'a rien pour ce pays. Toujours présent : sert de CTA
    /// même quand providerNames est vide.
    let justWatchURL: URL

    var isEmpty: Bool { providerNames.isEmpty }
}
