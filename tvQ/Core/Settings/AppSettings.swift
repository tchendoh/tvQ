import SwiftUI

enum ContentLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    case french = "fr-CA"

    var id: String { rawValue }

    /// Endonyme — le nom d'une langue reste le même peu importe la langue de l'interface.
    var displayName: LocalizedStringKey {
        switch self {
        case .english: "English"
        case .french: "Français"
        }
    }
}

/// Code pays ISO 3166-1 utilisé pour filtrer les diffuseurs retournés par
/// `TMDBClient.fetchWatchProviders` (voir WatchProvidersMapper) — TMDB renvoie
/// toutes les régions d'un coup, ce setting sert seulement à choisir laquelle
/// afficher. Liste volontairement courte (marchés les plus probables pour les
/// utilisateurs de tvQ) plutôt que la liste complète des ~60 pays TMDB.
enum WatchProviderRegion: String, CaseIterable, Identifiable {
    case canada = "CA"
    case unitedStates = "US"
    case france = "FR"
    case unitedKingdom = "GB"

    var id: String { rawValue }

    /// Chaîne brute (pas LocalizedStringKey) — utilisée par WatchAvailabilityMapper
    /// pour composer le texte "Watch (Canada) on ..." affiché dans ShowDetailView.
    var displayNameString: String {
        switch self {
        case .canada: "Canada"
        case .unitedStates: "United States"
        case .france: "France"
        case .unitedKingdom: "United Kingdom"
        }
    }

    var displayName: LocalizedStringKey {
        LocalizedStringKey(displayNameString)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Point d'accès unique aux préférences persistées localement (UserDefaults, via
/// @AppStorage côté vues). Pas de sync multi-appareils pour l'instant — un seul
/// appareil actif, décision prise avec l'utilisateur ; à reconsidérer si ça change.
enum AppSettings {
    enum Keys {
        static let contentLanguage = "settings.contentLanguage"
        static let appearance = "settings.appearance"
        static let useOriginalLanguage = "settings.useOriginalLanguage"
        static let watchProviderRegion = "settings.watchProviderRegion"
    }

    /// Lu par TMDBClient à l'initialisation — voir son paramètre `language`.
    static var contentLanguage: String {
        UserDefaults.standard.string(forKey: Keys.contentLanguage) ?? ContentLanguage.english.rawValue
    }

    /// Lu par WatchProvidersMapper pour choisir la région à afficher dans la
    /// section "Regarder sur" de ShowDetailView. Par défaut le Canada — la
    /// majorité des utilisateurs actuels de tvQ y sont.
    static var watchProviderRegion: String {
        UserDefaults.standard.string(forKey: Keys.watchProviderRegion) ?? WatchProviderRegion.canada.rawValue
    }

    /// Portée volontairement limitée à ShowDetailView + épisodes (pas la recherche) —
    /// voir discussion : dans une grille de résultats mélangeant plusieurs langues
    /// d'origine, ce serait un appel réseau par résultat affiché.
    static var useOriginalLanguage: Bool {
        UserDefaults.standard.bool(forKey: Keys.useOriginalLanguage)
    }

    /// Composant de clé de cache reflétant la langue effective des contenus
    /// TMDB récupérés (voir LocalEpisodeCache, FirestoreEpisodeCacheRepository,
    /// LocalShowCache, FirestoreShowCacheRepository). Nécessaire parce que le
    /// cache partagé Firestore est commun à tous les utilisateurs : sans ce
    /// composant, deux utilisateurs avec des préférences de langue différentes
    /// s'écraseraient mutuellement le cache avec la mauvaise langue.
    ///
    /// "original" plutôt que le code réel de la langue d'origine (ex. "ja") :
    /// ce code n'est connu qu'après une première résolution de la série, donc
    /// pas disponible au moment de construire la clé pour le tout premier appel.
    static var cacheLanguageKey: String {
        useOriginalLanguage ? "original" : contentLanguage
    }
}
