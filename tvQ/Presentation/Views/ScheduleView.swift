import SwiftUI

/// Horaire de diffusion : épisodes récemment diffusés (jusqu'à 7 jours, voir
/// RemoteScheduleRepository.recentlyAiredWindow) et à venir, toutes séries
/// suivies confondues, groupés par jour.
struct ScheduleView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "Coming soon",
                        systemImage: "calendar",
                        description: Text("Your upcoming episodes will show up here.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(daySections) { section in
                                Section {
                                    if section.groups.isEmpty {
                                        Text("Nothing today")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(section.groups) { group in
                                            NavigationLink(value: group.show) {
                                                ScheduleRow(group: group)
                                            }
                                        }
                                    }
                                } header: {
                                    ScheduleSectionHeader(section: section)
                                }
                                .id(section.day)
                            }
                        }
                        .listStyle(.plain)
                        // On atterrit sur "Aujourd'hui" plutôt qu'en haut de liste
                        // (qui montrerait d'abord les jours passés) — l'utilisateur
                        // scrolle vers le haut seulement s'il veut revoir les
                        // épisodes déjà diffusés.
                        .onChange(of: viewModel.items) {
                            scrollToToday(using: proxy)
                        }
                        .onAppear {
                            scrollToToday(using: proxy)
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .settingsToolbarItem()
            .navigationDestination(for: Show.self) { show in
                ShowDetailView(tmdbID: show.tmdbID)
            }
            .task(id: followedShowsStore.followedShowIDs) {
                viewModel.load(showIDs: followedShowsStore.followedShowIDs)
            }
        }
    }

    private func scrollToToday(using proxy: ScrollViewProxy) {
        let today = Calendar.current.startOfDay(for: Date())
        proxy.scrollTo(today, anchor: .top)
    }

    /// Regroupe les items par jour civil, puis par (série, saison) au sein d'un
    /// même jour — nécessaire parce que certaines séries sortent une saison
    /// complète en une fois (ex. Netflix) : sans ce regroupement, une seule
    /// sortie donnerait une ligne par épisode.
    ///
    /// La section "Aujourd'hui" est toujours présente, même vide — repère fixe
    /// pour l'utilisateur et point d'ancrage du scroll initial (voir scrollToToday).
    private var daySections: [DaySection] {
        let calendar = Calendar.current
        var itemsByDay = Dictionary(grouping: viewModel.items) { item in
            calendar.startOfDay(for: item.episode.bestAvailableDate ?? .distantFuture)
        }

        let today = calendar.startOfDay(for: Date())
        if itemsByDay[today] == nil {
            itemsByDay[today] = []
        }

        return itemsByDay.keys.sorted().map { day in
            let itemsForDay = itemsByDay[day] ?? []
            let bySeriesAndSeason = Dictionary(grouping: itemsForDay) { item in
                SeasonKey(showID: item.show.id, seasonNumber: item.episode.seasonNumber)
            }

            let groups = bySeriesAndSeason.values.compactMap { seasonItems -> EpisodeGroup? in
                guard let show = seasonItems.first?.show, let seasonNumber = seasonItems.first?.episode.seasonNumber else {
                    return nil
                }
                let episodeNumbers = seasonItems.map(\.episode.episodeNumber).sorted()
                let earliestDate = seasonItems.compactMap { $0.episode.bestAvailableDate }.min()
                return EpisodeGroup(show: show, seasonNumber: seasonNumber, episodeNumbers: episodeNumbers, date: earliestDate)
            }

            return DaySection(day: day, groups: groups.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) })
        }
    }

    private struct SeasonKey: Hashable {
        let showID: String
        let seasonNumber: Int
    }

    /// fileprivate (pas private) : ScheduleSectionHeader, hors du scope de
    /// ScheduleView, y référence directement.
    fileprivate struct DaySection: Identifiable {
        let day: Date
        let groups: [EpisodeGroup]
        var id: Date { day }

        /// Hier/Aujourd'hui/Demain d'abord (plus parlant qu'une date) ; puis le
        /// jour de semaine seul dans la semaine qui vient (ex. "Jeudi") — au-delà,
        /// le jour de semaine seul devient ambigu (quel jeudi ?), donc on revient
        /// à une date complète.
        var title: String {
            let calendar = Calendar.current

            if calendar.isDateInYesterday(day) {
                return String(localized: "Yesterday")
            } else if calendar.isDateInToday(day) {
                return String(localized: "Today")
            } else if calendar.isDateInTomorrow(day) {
                return String(localized: "Tomorrow")
            }

            let daysFromToday = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: day).day ?? 0
            if (0...6).contains(daysFromToday) {
                return day.formatted(.dateTime.weekday(.wide))
            }

            return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
    }

    /// Un ou plusieurs épisodes d'une même série/saison sortis le même jour.
    /// fileprivate (pas private) : ScheduleRow, hors du scope de ScheduleView,
    /// y référence directement.
    fileprivate struct EpisodeGroup: Identifiable {
        let show: Show
        let seasonNumber: Int
        let episodeNumbers: [Int]
        let date: Date?
        var id: String { "\(show.id)-\(seasonNumber)-\(episodeNumbers)" }
    }
}

/// En-tête de section : jour à gauche ("Demain"), date complète à droite
/// ("21 juil. 2026") — repris de l'ancienne version de tvQ (tvQ-legacy).
private struct ScheduleSectionHeader: View {
    let section: ScheduleView.DaySection

    var body: some View {
        HStack {
            Text(section.title)
            Spacer()
            Text(section.day, format: .dateTime.day().month(.abbreviated).year())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct ScheduleRow: View {
    let group: ScheduleView.EpisodeGroup

    /// Un épisode est "déjà diffusé" si sa date est passée — affiche le badge
    /// "Aired", peu importe le jour.
    private var hasAlreadyAired: Bool {
        guard let date = group.date else { return false }
        return date < Date()
    }

    /// Contrairement à hasAlreadyAired, ne s'applique qu'aux jours *précédant*
    /// aujourd'hui. Un épisode diffusé aujourd'hui doit rester bien visible :
    /// c'est justement le rôle de cet écran de le mettre en évidence pour que
    /// l'utilisateur puisse le rattraper, pas de le faire disparaître dans le fond.
    private var shouldDim: Bool {
        guard let date = group.date else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RetryingAsyncImage(url: group.show.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Rectangle().fill(.secondary.opacity(0.15))
                    Image(systemName: "tv")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(group.show.title)
                    .font(.headline)

                // Reprise de l'ancienne version de tvQ (tvQ-legacy) : un tag par
                // épisode plutôt qu'un résumé texte ("Saison X — N épisodes") —
                // reste lisible même quand une saison complète sort le même jour.
                FlowLayout(spacing: 6) {
                    ForEach(group.episodeNumbers, id: \.self) { episodeNumber in
                        EpisodeTag(
                            text: String(format: "S%02dE%02d", group.seasonNumber, episodeNumber),
                            style: .episode
                        )
                        if episodeNumber == 1 {
                            EpisodeTag(text: String(localized: "Premiere"), style: .premiere)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if hasAlreadyAired {
                Text("Aired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(shouldDim ? 0.6 : 1)
        .padding(.vertical, 4)
    }
}

/// Petit badge arrondi façon "tag" — repris de l'ancienne version de tvQ
/// (tvQ-legacy) pour l'affichage des numéros d'épisode.
private struct EpisodeTag: View {
    enum Style {
        case episode
        case premiere
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
            .foregroundStyle(.white)
    }

    private var backgroundColor: Color {
        switch style {
        case .episode: .green
        case .premiere: .pink
        }
    }
}

/// Layout simple qui enchaîne ses enfants horizontalement et retourne à la
/// ligne quand ça déborde — nécessaire pour les tags d'épisode, dont le
/// nombre varie (1 à N par sortie groupée).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ScheduleView()
        .environment(FollowedShowsStore())
}
