import SwiftUI

struct MyShowsView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel = MyShowsViewModel()

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
                        LazyVGrid(columns: gridColumns, spacing: 24) {
                            ForEach(viewModel.shows) { show in
                                NavigationLink(value: show) {
                                    ShowCardView(
                                        title: show.title,
                                        posterURL: show.posterURL,
                                        isFollowed: true,
                                        onToggleFollow: { followedShowsStore.toggle(showID: show.id) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
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

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 24)]
    }
}

#Preview {
    MyShowsView()
        .environment(AuthViewModel())
        .environment(FollowedShowsStore())
}
