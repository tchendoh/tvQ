import SwiftUI

/// Appelle `action` quand la langue des contenus TMDB change dans les réglages
/// (langue choisie, ou « Prefer show's original language »).
///
/// Les nouvelles requêtes suivent déjà le réglage (TMDBService le lit à chaque
/// appel, et les caches sont rangés par langue), mais un écran déjà chargé garde
/// en mémoire les données de l'ancienne langue. Chaque écran concerné s'en sert
/// pour se recharger, sans perdre l'onglet ni la position de défilement.
///
/// Ne se déclenche pas à l'apparition : le chargement initial reste à .task.
private struct ContentLanguageChangeModifier: ViewModifier {
    @AppStorage(AppSettings.Keys.contentLanguage)
    private var contentLanguage: String = ContentLanguage.interfaceDefault.rawValue

    @AppStorage(AppSettings.Keys.useOriginalLanguage)
    private var useOriginalLanguage = false

    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: "\(contentLanguage)|\(useOriginalLanguage)") {
            action()
        }
    }
}

extension View {
    func onContentLanguageChange(perform action: @escaping () -> Void) -> some View {
        modifier(ContentLanguageChangeModifier(action: action))
    }
}
