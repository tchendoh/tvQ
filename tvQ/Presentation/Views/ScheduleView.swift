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
                                Section(section.title) {
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

    private struct DaySection: Identifiable {
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

private struct ScheduleRow: View {
    let group: ScheduleView.EpisodeGroup

    /// Un épisode est "déjà diffusé" si sa date est passée — atténué visuellement
    /// pour que l'œil se porte d'abord sur ce qui s'en vient.
    private var hasAlreadyAired: Bool {
        guard let date = group.date else { return false }
        return date < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: group.show.posterURL) { image in
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

            VStack(alignment: .leading, spacing: 4) {
                Text(group.show.title)
                    .font(.headline)

                Text(episodeLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasAlreadyAired {
                Text("Aired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(hasAlreadyAired ? 0.6 : 1)
        .padding(.vertical, 4)
    }

    /// Un seul épisode : format SxxExx habituel. Plusieurs (sortie groupée
    /// d'une saison complète) : "Saison X — N épisodes", plus lisible qu'une
    /// plage de numéros.
    private var episodeLabel: String {
        if group.episodeNumbers.count == 1 {
            return String(format: "S%02dE%02d", group.seasonNumber, group.episodeNumbers[0])
        } else {
            return String(
                format: String(localized: "Season %d — %d episodes"),
                group.seasonNumber,
                group.episodeNumbers.count
            )
        }
    }
}

#Preview {
    ScheduleView()
        .environment(FollowedShowsStore())
}
