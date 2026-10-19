import SwiftUI

struct MyShowsView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel = MyShowsViewModel()
    @State private var selectedTMDBID: Int?
    /// Filtre des séries suivies (champ de recherche en haut de la liste).
    @State private var searchText = ""
    /// Section « Ended » repliée par défaut : ce sont les séries qu'on consulte le
    /// moins. Le choix est retenu d'un lancement à l'autre.
    @AppStorage("myShows.isEndedExpanded") private var isEndedExpanded = false
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
                } else if isSearching && filtered(viewModel.shows).isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            section(title: Text("Ongoing"), shows: filtered(viewModel.ongoingShows))
                            endedSection
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("My Shows")
            .searchable(text: $searchText, prompt: Text("Filter your shows"))
            .presentsShowDetailSheet(tmdbID: $selectedTMDBID)
            .settingsToolbarItem()
            .task(id: followedShowsStore.followedShowIDs) {
                viewModel.load(showIDs: followedShowsStore.followedShowIDs)
            }
            .onContentLanguageChange {
                viewModel.load(showIDs: followedShowsStore.followedShowIDs, reloadAll: true)
            }
        }
    }

    // MARK: - Filtre

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Séries dont le titre contient le texte cherché (sans tenir compte de la casse
    /// ni des accents : « eche » trouve « L'Échappée »).
    private func filtered(_ shows: [Show]) -> [Show] {
        guard isSearching else { return shows }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return shows.filter { $0.title.localizedStandardContains(query) }
    }

    // MARK: - Sections

    /// Repliable ; toujours dépliée pendant une recherche, sinon les résultats
    /// terminés seraient cachés.
    @ViewBuilder
    private var endedSection: some View {
        let shows = filtered(viewModel.endedShows)
        if !shows.isEmpty {
            let isExpanded = isEndedExpanded || isSearching
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy) { isEndedExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Ended")
                            .font(.title3.weight(.semibold))
                        Text(verbatim: "\(shows.count)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSearching)
                .padding(.horizontal, 20)
                .accessibilityHint(isExpanded ? Text("Collapses the section.") : Text("Expands the section."))

                if isExpanded {
                    grid(shows: shows, isUnfollowButtonVisible: true)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: Text, shows: [Show]) -> some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                title
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)

                grid(shows: shows, isUnfollowButtonVisible: false)
            }
        }
    }

    private func grid(shows: [Show], isUnfollowButtonVisible: Bool) -> some View {
        EvenGrid(items: shows, minimumWidth: cardMinimumWidth) { show in
            Button { selectedTMDBID = show.tmdbID } label: {
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

#Preview {
    MyShowsView()
        .environment(SessionStore())
        .environment(FollowedShowsStore())
}
