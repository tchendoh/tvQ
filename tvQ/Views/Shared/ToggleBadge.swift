import SwiftUI

/// Pastille ronde des interrupteurs d'une série posés sur une image (suivi et
/// cloche, cartes et fiche). Choisie le 2026-10-21 dans Debug › Style Lab
/// (variante C) : verre quand l'interrupteur est inactif, disque plein quand il
/// est actif (symbole foncé sur disque clair), pour que l'état se lise d'un coup
/// d'œil et que les deux interrupteurs se ressemblent.
///
/// Le symbole ne porte pas de cercle : la pastille le fournit.
struct ToggleBadgeLabel: View {
    let systemImage: String
    let isOn: Bool
    /// Couleur du symbole et du contour à l'état inactif (rose pour « Suivre »,
    /// gris pour une cloche coupée).
    let offColor: Color

    var body: some View {
        Image(systemName: systemImage)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
            .symbolEffect(.bounce, value: isOn)
            // Suit Dynamic Type.
            .font(.headline.weight(.bold))
            .foregroundStyle(isOn ? Color.black : offColor)
            .frame(width: 34, height: 34)
            .background {
                if isOn {
                    Circle().fill(Color.emphasis)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Circle().strokeBorder((isOn ? Color.emphasis : offColor).opacity(0.5), lineWidth: 1)
            }
            // La pastille flotte sur des affiches très variables (claires, sombres,
            // saturées) : mode sombre forcé pour que le matériau et Color.emphasis
            // restent lisibles peu importe l'image en dessous.
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .sensoryFeedback(.impact(weight: .light), trigger: isOn)
    }
}
