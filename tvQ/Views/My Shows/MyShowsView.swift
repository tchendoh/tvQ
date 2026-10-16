import SwiftUI

struct MyShowsView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel = MyShowsViewModel()
    /// Largeur minimale d'une carte, qui grandit avec la taille du texte choisie
    /// dans les réglages d'accessibilité.
    @ScaledMetric(relativeTo: .body) private var cardMinimumWidth = ShowCardView.baseMinimumWidth

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.shows.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.shows.isEmpty {
                    ContentUnavailableView(
                        "No shows followed",
                        systemImage: "tv",
                        description: Text("Shows you follow will show up here.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            section(title: "Running", shows: viewModel.currentShows)
                            section(title: "Season ended", shows: viewModel.seasonEndedShows)
                            section(title: "Coming soon", shows: viewModel.upcomingShows)
                            section(title: "Ended", shows: viewModel.endedShows, isUnfollowButtonVisible: true)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("My Shows")
            .settingsToolbarItem()
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(tmdbID: show.tmdbID)
            }
            .task(id: followedShowsStore.followedShowIDs) {
                viewModel.load(showIDs: followedShowsStore.followedShowIDs)
            }
        }
    }

    @ViewBuilder
    private func section(
        title: LocalizedStringKey,
        shows: [Show],
        isUnfollowButtonVisible: Bool = false
    ) -> some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)

                EvenGrid(items: shows, minimumWidth: cardMinimumWidth) { show in
                    NavigationLink(value: show) {
                        ShowCardView(
                            title: show.title,
                            posterURL: show.posterURL,
                            isFollowed: isUnfollowButtonVisible ? true : nil,
                            onToggleFollow: isUnfollowButtonVisible
                                ? { followedShowsStore.toggle(showID: show.id) }
                                : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    MyShowsView()
        .environment(SessionStore())
        .environment(FollowedShowsStore())
}
