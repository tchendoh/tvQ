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
    }

    /// Lu par TMDBClient à l'initialisation — voir son paramètre `language`.
    static var contentLanguage: String {
        UserDefaults.standard.string(forKey: Keys.contentLanguage) ?? ContentLanguage.english.rawValue
    }

    /// Portée volontairement limitée à ShowDetailView + épisodes (pas la recherche) —
    /// voir discussion : dans une grille de résultats mélangeant plusieurs langues
    /// d'origine, ce serait un appel réseau par résultat affiché.
    static var useOriginalLanguage: Bool {
        UserDefaults.standard.bool(forKey: Keys.useOriginalLanguage)
    }
}
