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
    @AppStorage("myShows.sortOrder") private var sortOrder: MyShowsViewModel.SortOrder = .recent
    @AppStorage("myShows.layout") private var layout: Layout = .grid

    enum Layout: String {
        case grid
        case list
    }
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
                            section(title: Text("Ongoing"), shows: viewModel.sorted(filtered(viewModel.ongoingShows), by: sortOrder))
                            endedSection
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("My Shows")
            .searchable(text: $searchText, prompt: Text("Filter your shows"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    displayMenu
                }
            }
            // Base locale modifiée (horaire rafraîchi) : relit l'épisode le plus proche.
            .task(id: LocalDataVersion.shared.value) {
                await viewModel.refreshNearestEpisodes()
            }
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
        // Toujours par titre : les séries terminées n'ont plus d'épisode proche.
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

    // MARK: - Affichage

    private var displayMenu: some View {
        Menu {
            Picker(selection: $sortOrder) {
                Label("Recent activity", systemImage: "clock").tag(MyShowsViewModel.SortOrder.recent)
                Label("Title", systemImage: "textformat").tag(MyShowsViewModel.SortOrder.title)
            } label: {
                Text("Sort by")
            }
            .pickerStyle(.inline)

            Picker(selection: $layout.animation(.snappy)) {
                Label("Grid", systemImage: "square.grid.2x2").tag(Layout.grid)
                Label("List", systemImage: "list.bullet").tag(Layout.list)
            } label: {
                Text("View as")
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .accessibilityLabel(Text("Sort and view options"))
        }
    }

    @ViewBuilder
    private func grid(shows: [Show], isUnfollowButtonVisible: Bool) -> some View {
        switch layout {
        case .grid:
            cards(shows: shows, isUnfollowButtonVisible: isUnfollowButtonVisible)
        case .list:
            rows(shows: shows, isUnfollowButtonVisible: isUnfollowButtonVisible)
        }
    }

    private func rows(shows: [Show], isUnfollowButtonVisible: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(shows.enumerated()), id: \.element.id) { index, show in
                if index > 0 {
                    Divider()
                        .padding(.leading, 56)
                }
                Button { selectedTMDBID = show.tmdbID } label: {
                    ShowListRow(
                        show: show,
                        episode: viewModel.nearestEpisodes[show.id],
                        onUnfollow: isUnfollowButtonVisible
                            ? { followedShowsStore.toggle(showID: show.id) }
                            : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func cards(shows: [Show], isUnfollowButtonVisible: Bool) -> some View {
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

/// Rangée de l'affichage en liste : petite affiche, titre, et l'épisode le plus
/// proche (« S03E05 · Tomorrow »), sinon le diffuseur.
private struct ShowListRow: View {
    let show: Show
    let episode: Episode?
    let onUnfollow: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            RetryingAsyncImage(url: show.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.secondary.opacity(0.15))
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(show.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let detail {
                    Text(verbatim: detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let onUnfollow {
                Button(action: onUnfollow) {
                    FollowIcon(isFollowing: true)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Unfollow"))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var detail: String? {
        if let episode, let day = Self.localDay(of: episode) {
            return "\(episode.code) · \(Self.dayLabel(day))"
        }
        return show.network
    }

    /// Jour de diffusion dans le fuseau de l'appareil. Une date seule (TMDB) est
    /// stockée à minuit UTC : la convertir telle quelle donnerait la veille à
    /// Montréal. On garde donc son jour tel quel.
    static func localDay(of episode: Episode) -> Date? {
        guard let date = episode.airDate else { return nil }
        guard !episode.hasPreciseTime else { return Calendar.current.startOfDay(for: date) }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        return Calendar.current.date(from: utc.dateComponents([.year, .month, .day], from: date))
    }

    /// Hier, aujourd'hui, demain ; puis le jour de semaine dans la semaine qui vient
    /// ou qui vient de passer ; sinon la date.
    static func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let offset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch offset {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case -1: return String(localized: "Yesterday")
        case -6...6: return day.formatted(.dateTime.weekday(.wide))
        default: return day.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

#Preview {
    MyShowsView()
        .environment(SessionStore())
        .environment(FollowedShowsStore())
}
