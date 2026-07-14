import SwiftUI

/// Carte compacte affiche + titre — composant réutilisable pour toute grille de
/// séries (résultats de recherche, "Mes séries" plus tard). Pas de synopsis ici,
/// volontairement : le détail a sa place dans ShowDetailView, pas dans une grille.
struct ShowCardView: View {
    let title: String
    let posterURL: URL?

    /// nil = pas de badge (état de suivi pas encore connu/chargé, ou non pertinent
    /// pour cet écran). true = crochet vert (suivie), false = "+" (pas suivie).
    var isFollowed: Bool? = nil

    /// nil = badge purement indicatif, non tapable. Non-nil = badge interactif :
    /// un tap bascule le suivi sans ouvrir ShowDetailView — inspiré de l'ancienne
    /// version de tvQ, où ce geste évitait d'ouvrir la fiche juste pour suivre une série.
    var onToggleFollow: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Rectangle().fill(.secondary.opacity(0.15))
                    Image(systemName: "tv")
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(2 / 3, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
            .overlay(alignment: .topTrailing) {
                if let isFollowed {
                    FollowBadge(isFollowed: isFollowed, action: onToggleFollow)
                        .padding(6)
                        .offset(x: 2, y: -2)
                }
            }

            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
        }
    }
}

/// Reprise fidèle de FollowButton.swift dans tvQ-legacy (github.com/tchendoh/tvQ-legacy) :
/// carré arrondi noir, viseur+ rose pour "pas suivie", crochet vert pour "suivie",
/// avec l'animation bounce + morph au toggle. Ici sans état interne — isFollowed
/// vient de FollowedShowsStore, la seule source de vérité.
private struct FollowBadge: View {
    let isFollowed: Bool
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button {
                    withAnimation(.spring) { action() }
                } label: {
                    icon
                }
                .buttonStyle(.plain)
            } else {
                icon
            }
        }
        .frame(width: 30, height: 30)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
    }

    private var icon: some View {
        Image(systemName: isFollowed ? "checkmark.circle" : "plus.viewfinder")
            .font(.system(size: 20, weight: .bold))
            .symbolRenderingMode(.palette)
            .symbolEffect(.bounce, value: isFollowed)
            // .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(isFollowed ? .green : .pink, isFollowed ? .green : .pink)
    }
}

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var isFollowed = false

    var body: some View {
        HStack(spacing: 16) {
            ShowCardView(title: "Breaking Bad", posterURL: nil, isFollowed: true)
            ShowCardView(
                title: "The Wire",
                posterURL: nil,
                isFollowed: isFollowed,
                onToggleFollow: { isFollowed.toggle() }
            )
            ShowCardView(title: "No badge here", posterURL: nil)
        }
        .frame(width: 160)
        .padding()
    }
}
