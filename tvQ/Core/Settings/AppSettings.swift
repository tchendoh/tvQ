import SwiftUI

enum ContentLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    /// "fr" sans région : TMDB renvoie alors la traduction principale (fr-FR),
    /// bien mieux couverte que fr-CA, qui laisse souvent des résumés vides.
    case french = "fr"

    var id: String { rawValue }

    /// Langue de contenu tant que l'utilisateur n'a rien choisi : celle dans
    /// laquelle l'interface de tvQ s'affiche réellement (String Catalog en "fr").
    /// Rien n'est écrit dans UserDefaults, donc la valeur suit l'appareil.
    static var interfaceDefault: ContentLanguage {
        let ui = Bundle.main.preferredLocalizations.first ?? "en"
        return ui.hasPrefix("fr") ? .french : .english
    }

    /// Endonyme — le nom d'une langue reste le même peu importe la langue de l'interface.
    var displayName: LocalizedStringKey {
        switch self {
        case .english: "English"
        case .french: "Français"
        }
    }
}

enum AppSettings {
    enum Keys {
        static let contentLanguage = "settings.contentLanguage"
        static let useOriginalLanguage = "settings.useOriginalLanguage"
        static let watchProviderRegion = "settings.watchProviderRegion"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let notificationTiming = "settings.notificationTiming"
        /// Minutes depuis minuit (540 = 9 h).
        static let notificationMorningMinutes = "settings.notificationMorningMinutes"
        static let liveActivitiesEnabled = "settings.liveActivitiesEnabled"
        static let appearance = "settings.appearance"
        /// Réglages internes (Settings › Debug) : voir `TabHaptic`.
        static let tabHaptic = "settings.debug.tabHaptic"
        static let tabHapticIntensity = "settings.debug.tabHapticIntensity"
    }

    /// Lu par TMDBService à l'initialisation — voir son paramètre `language`.
    static var contentLanguage: String {
        UserDefaults.standard.string(forKey: Keys.contentLanguage) ?? ContentLanguage.interfaceDefault.rawValue
    }

    /// Ancienne valeur "fr-CA" (avant le 2026-10-26) ramenée à "fr". Appelé au lancement.
    static func migrateLegacyContentLanguage() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Keys.contentLanguage) == "fr-CA" {
            defaults.set(ContentLanguage.french.rawValue, forKey: Keys.contentLanguage)
        }
    }

    /// Pays (ISO 3166-1, ex. "CA") des diffuseurs affichés dans ShowDetailView.
    /// Par défaut la région de l'appareil (Réglages › Général › Langue et région) ;
    /// la clé n'est écrite que si l'utilisateur choisit un autre pays depuis la
    /// fiche d'une série. TMDB renvoie tous les pays d'un coup : n'importe quel
    /// code fonctionne, et un pays sans données mène au lien JustWatch.
    static var watchProviderRegion: String {
        UserDefaults.standard.string(forKey: Keys.watchProviderRegion) ?? deviceRegion
    }

    /// Région de l'appareil, ou le Canada si iOS n'en fournit pas.
    nonisolated static var deviceRegion: String {
        Locale.current.region?.identifier ?? "CA"
    }

    /// Nom du pays dans la langue de l'interface (« Canada », « États-Unis »).
    nonisolated static func regionDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Portée volontairement limitée à ShowDetailView + épisodes (pas la recherche) :
    /// dans une grille de résultats mélangeant plusieurs langues d'origine, ce
    /// serait un appel réseau par résultat affiché.
    static var useOriginalLanguage: Bool {
        UserDefaults.standard.bool(forKey: Keys.useOriginalLanguage)
    }

    /// Composant de clé de cache reflétant la langue effective des contenus
    /// TMDB récupérés (voir EpisodeStore, ShowStore et les caches Firestore
    /// partagés). Nécessaire parce que le
    /// cache partagé Firestore est commun à tous les utilisateurs : sans ce
    /// composant, deux utilisateurs avec des préférences de langue différentes
    /// s'écraseraient mutuellement le cache avec la mauvaise langue.
    ///
    /// "original" plutôt que le code réel de la langue d'origine (ex. "ja") :
    /// ce code n'est connu qu'après une première résolution de la série, donc
    /// pas disponible au moment de construire la clé pour le tout premier appel.
    static let defaultMorningMinutes = 9 * 60

    static var cacheLanguageKey: String {
        useOriginalLanguage ? "original" : contentLanguage
    }
}

/// Settings › Appearance : suivre iOS, ou forcer le mode clair ou sombre pour tvQ seulement.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var displayName: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil : laisse iOS décider (réglage System).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
