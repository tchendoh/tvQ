import SwiftUI

#if DEBUG
/// Debug › Style Lab : banc d'essai pour comparer des variantes visuelles côte à
/// côte avant d'en retenir une. Vidé le 2026-10-22 une fois les choix faits
/// (pastilles de suivi et de cloche, bouton de suivi de la fiche, pastille de
/// statut) ; l'historique Git garde les anciennes comparaisons. Textes non
/// traduits (debug).
struct StyleLabView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(verbatim: "Nothing to compare")
            } icon: {
                Image(systemName: "paintpalette")
            }
        } description: {
            Text(verbatim: "Add variants here when a style choice needs comparing.")
        }
        .navigationTitle(Text(verbatim: "Style Lab"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        StyleLabView()
    }
}
#endif
