import SwiftUI

extension View {
    /// Icône Settings cohérente sur les trois onglets — l'accès aux réglages ne
    /// doit pas dépendre de l'onglet où on se trouve. Nécessite d'être appelé
    /// à l'intérieur du NavigationStack de chaque onglet.
    func settingsToolbarItem() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}
