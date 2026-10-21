import Foundation

/// Où regarder une série dans un pays donné (streaming, achat ou location),
/// dérivé de `TMDBWatchProvidersDTO` pour la région choisie par l'utilisateur
/// (voir AppSettings.watchProviderRegion). Texte seulement dans l'UI —
/// pas de logos (jugés pas assez propres visuellement, voir ShowDetailView).
nonisolated struct WatchAvailability: Equatable, Codable {
    /// Nom du pays affiché à l'utilisateur (ex. "Canada"), pas le code ISO brut.
    let regionDisplayName: String

    /// Diffuseurs regroupés par façon de regarder, chacun dédupliqué (un nom
    /// n'apparaît que dans le premier groupe qui le contient) :
    /// inclus dans un abonnement (`flatrate`)…
    let included: [String]
    /// …gratuit, avec ou sans publicité (`free`, `ads`)…
    let free: [String]
    /// …achat ou location (`buy`, `rent`), rarement utile à distinguer.
    let buyOrRent: [String]

    /// Lien retourné par TMDB pour cette région (pointe vers themoviedb.org,
    /// qui redirige lui-même vers JustWatch — TMDB ne fournit pas de deep-link
    /// direct, voir WatchAvailabilityMapper), ou repli sur la page d'accueil
    /// JustWatch si TMDB n'a rien pour ce pays. Toujours présent : sert de CTA
    /// même quand providerNames est vide.
    let justWatchURL: URL

    /// Codes des pays pour lesquels TMDB a au moins un diffuseur pour cette série :
    /// alimente le menu de choix du pays dans ShowDetailView. (Un ancien cache sans
    /// ce champ ne se décode plus et est simplement rechargé.)
    var availableRegions: [String] = []

    /// Tous les diffuseurs, dans l'ordre d'affichage. Vide si TMDB n'a aucune
    /// donnée pour ce pays : l'UI affiche alors un lien vers JustWatch.
    var providerNames: [String] { included + free + buyOrRent }

    var isEmpty: Bool { providerNames.isEmpty }
}
