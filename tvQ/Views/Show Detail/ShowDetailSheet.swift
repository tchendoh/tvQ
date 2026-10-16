import SwiftUI

extension View {
    /// Fiche de série dans un sheet non modal qui reste ouvert : le parent
    /// passe la série sélectionnée comme une donnée qui peut changer (binding),
    /// et la fiche suit. Toucher une autre série en arrière-plan met donc la
    /// fiche à jour au lieu de fermer et rouvrir le sheet (modèle du panneau
    /// de mise en forme de Notes, cité par la HIG pour les sheets non modaux).
    ///
    /// sheet(isPresented:) plutôt que sheet(item:) : avec item, changer
    /// l'élément pendant que le sheet est ouvert le ferme et en présente un
    /// nouveau. Ici, le sheet est présenté tant que tmdbID n'est pas nil, et
    /// le fermer remet tmdbID à nil.
    func presentsShowDetailSheet(tmdbID: Binding<Int?>) -> some View {
        sheet(isPresented: Binding(
            get: { tmdbID.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { tmdbID.wrappedValue = nil }
            }
        )) {
            ShowDetailSheet(tmdbID: tmdbID)
        }
        // L'écran qui présente le sheet disparaît (changement d'onglet, écran
        // poussé par-dessus comme les Réglages) : la fiche n'a plus de
        // contexte, on la ferme. Chaque écran gère ainsi son propre sheet sans
        // rien savoir des onglets.
        .onDisappear { tmdbID.wrappedValue = nil }
    }
}

/// Contenu du sheet. Reçoit un binding plutôt qu'une valeur : un binding se
/// relit à chaque mise à jour, alors qu'une valeur capturée à la présentation
/// resterait figée (c'est ce qui donnait un sheet vide auparavant).
struct ShowDetailSheet: View {
    @Binding var tmdbID: Int?

    var body: some View {
        NavigationStack {
            if let tmdbID {
                // Pas de .id ici : ShowDetailView suit elle-même le changement
                // de série avec .task(id: tmdbID).
                ShowDetailView(tmdbID: tmdbID)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                self.tmdbID = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
        }
        // Hors du if : appliqués au sheet quoi qu'il arrive.
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
    }
}
