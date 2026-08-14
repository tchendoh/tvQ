import SwiftUI

extension Color {
    /// Accent neutre utilisé pour mettre en évidence un bloc "actif" (ex. le
    /// jour courant dans Schedule) sans dépendre du bleu d'accent système —
    /// quasi noir (#101010) en mode clair, quasi blanc en mode sombre, pour
    /// garder le même "genre" de contraste fort dans les deux thèmes.
    static var emphasis: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.93, alpha: 1)
                : UIColor(red: 0x10 / 255, green: 0x10 / 255, blue: 0x10 / 255, alpha: 1)
        })
    }
}

/// Bloc visuel générique : un en-tête et un contenu regroupés dans un même
/// conteneur délimité (fond, coins arrondis, bordure d'accent optionnelle).
///
/// Vocabulaire visuel commun pour toute vue qui a besoin de regrouper des
/// éléments sous une même unité clairement délimitée (ex. les jours de
/// Schedule) — plutôt que de réinventer un traitement de "carte" différent
/// à chaque écran, ce qui finit par donner une app incohérente d'un onglet
/// à l'autre.
struct GroupedCard<Header: View, Content: View>: View {
    var isHighlighted: Bool = false
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    private var cornerRadius: CGFloat { 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()
                .overlay(isHighlighted ? Color.emphasis.opacity(0.4) : Color.secondary.opacity(0.2))

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(isHighlighted ? Color.emphasis.opacity(0.6) : .clear, lineWidth: 1.5)
        }
    }
}
