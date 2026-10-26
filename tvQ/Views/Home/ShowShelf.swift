import SwiftUI

/// Rangée horizontale d'affiches de la page Accueil : titre, sous-titre (la source
/// de la liste), lien « See all » vers la grille complète (ShowGridPage).
/// Rien n'est affiché si la liste est vide.
struct ShowShelf: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let shows: [ShowSummary]
    @Binding var selectedTMDBID: Int?

    /// Plus étroite que dans les grilles (150) : laisse voir le début de la
    /// carte suivante, signe qu'on peut faire défiler.
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 128
    @Environment(FollowedShowsStore.self) private var followedShowsStore

    var body: some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                header
                    .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(shows) { summary in
                            card(summary)
                                .frame(width: cardWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                // Laisse la place à l'ombre des affiches.
                .contentMargins(.vertical, 6, for: .scrollContent)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            NavigationLink {
                ShowGridPage(title: title, subtitle: subtitle, shows: shows)
            } label: {
                Text("See all")
                    .font(.subheadline)
            }
        }
    }

    private func card(_ summary: ShowSummary) -> some View {
        let showID = String(summary.tmdbID)
        return Button { selectedTMDBID = summary.tmdbID } label: {
            ShowCardView(
                title: summary.title,
                posterURL: summary.posterURL,
                isFollowed: followedShowsStore.isFollowing(showID),
                onToggleFollow: { followedShowsStore.toggle(showID: showID) }
            )
        }
        .buttonStyle(.plain)
    }
}

/// Liste complète d'une rangée (« See all »), dans la grille habituelle.
/// Gère son propre sheet : celui de la page Accueil se ferme quand elle disparaît.
struct ShowGridPage: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let shows: [ShowSummary]

    @ScaledMetric(relativeTo: .body) private var cardMinimumWidth = ShowCardView.baseMinimumWidth
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var selectedTMDBID: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                EvenGrid(items: shows, minimumWidth: cardMinimumWidth) { summary in
                    let showID = String(summary.tmdbID)
                    Button { selectedTMDBID = summary.tmdbID } label: {
                        ShowCardView(
                            title: summary.title,
                            posterURL: summary.posterURL,
                            isFollowed: followedShowsStore.isFollowing(showID),
                            onToggleFollow: { followedShowsStore.toggle(showID: showID) }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .presentsShowDetailSheet(tmdbID: $selectedTMDBID)
    }
}
