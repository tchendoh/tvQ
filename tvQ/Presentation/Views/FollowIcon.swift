import SwiftUI

/// Icône + couleur du statut de suivi d'une série — crochet vert (suivie) ou
/// viseur rose (pas suivie). Seule source de vérité pour cette apparence,
/// partagée entre FollowBadge (ShowCardView, sur les grilles) et le bouton
/// "Suivre" de ShowDetailView, pour que le suivi soit visuellement cohérent
/// peu importe l'écran.
struct FollowIcon: View {
    let isFollowing: Bool

    var body: some View {
        Image(systemName: isFollowing ? "checkmark.circle" : "plus.viewfinder")
            .symbolRenderingMode(.palette)
            .symbolEffect(.bounce, value: isFollowing)
            .foregroundStyle(isFollowing ? .green : .pink, isFollowing ? .green : .pink)
    }
}
