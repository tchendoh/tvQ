import SwiftUI

/// Icône + couleur du statut de suivi d'une série. Seule source de vérité
/// pour cette apparence, partagée entre FollowBadge (ShowCardView, sur les
/// grilles) et le bouton "Suivre" de ShowDetailView, pour que le suivi soit
/// visuellement cohérent peu importe l'écran.
///
/// La couleur suit la même grammaire que le reste de l'app (voir
/// GroupedCard.Color.emphasis, EpisodeTag) : l'accent signale "il y a une
/// action à poser ici", pas "cette action est déjà faite" — donc c'est
/// l'état "pas suivi" (invite à suivre) qui reçoit l'accent, et "suivi" qui
/// redevient neutre une fois l'action posée.
struct FollowIcon: View {
    let isFollowing: Bool

    /// Seule source de vérité pour la couleur par état — évite qu'elle soit
    /// redérivée séparément là où on ne peut pas juste appliquer
    /// foregroundStyle à FollowIcon (ex. .tint() du bouton toolbar glass de
    /// ShowDetailView, ou le contour de FollowBadge).
    static func tintColor(isFollowing: Bool) -> Color {
        isFollowing ? Color.emphasis : .accentColor
    }

    var body: some View {
        Image(systemName: isFollowing ? "checkmark.circle" : "plus.viewfinder")
            // Transition "magic" entre les deux symboles (plus voyante qu'un simple
            // fondu), avec repli sur un downUp là où magic n'est pas applicable.
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp), options: .speed(1.2)))
            .symbolEffect(.bounce, value: isFollowing)
            // Une seule couleur par état désormais (plus besoin de bicolore
            // comme à l'époque du vert/rose) — foregroundStyle simple plutôt
            // que symbolRenderingMode(.palette), qui pouvait échouer à
            // résoudre une Color dynamique (Color.emphasis) par couche du
            // symbole et rendre l'icône invisible.
            .foregroundStyle(Self.tintColor(isFollowing: isFollowing))
            .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }
}
