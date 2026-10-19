import SwiftUI

/// Horaire de diffusion : épisodes récemment diffusés (jusqu'à 7 jours, voir
/// ScheduleRepository.recentlyAiredWindow) et à venir, toutes séries
/// suivies confondues, groupés par jour.
struct ScheduleView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @Environment(ScheduleViewModel.self) private var viewModel
    @State private var selectedTMDBID: Int?
    /// Position de défilement, visée par l'id (le jour) de chaque section.
    @State private var scrollPosition = ScrollPosition(idType: Date.self)
    /// Vrai tant que la liste doit rester sur "Aujourd'hui" pendant la mise en page ;
    /// faux dès que l'utilisateur fait défiler lui-même.
    @State private var isAnchoredToToday = true
    /// Vrai entre un deuxième toucher sur l'onglet et la fin du défilement d'iOS
    /// vers le haut (voir onScrollPhaseChange).
    @State private var returnsToTodayWhenIdle = false

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
                    ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(daySections) { section in
                                    GroupedCard(isHighlighted: section.isToday) {
                                        ScheduleSectionHeader(section: section)
                                    } content: {
                                        if section.groups.isEmpty {
                                            Text("Nothing today")
                                                .foregroundStyle(.secondary)
                                        } else {
                                            VStack(spacing: 0) {
                                                ForEach(Array(section.groups.enumerated()), id: \.element.id) { index, group in
                                                    if index > 0 {
                                                        Divider()
                                                            .padding(.vertical, 10)
                                                    }
                                                    Button { selectedTMDBID = group.show.tmdbID } label: {
                                                        ScheduleRow(group: group)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                    .id(section.day)
                                }
                            }
                            // Chaque section (jour) est une cible : ScrollPosition vise son id.
                            .scrollTargetLayout()
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .scrollPosition($scrollPosition, anchor: .top)
                        // On atterrit sur "Aujourd'hui" plutôt qu'en haut de liste
                        // (qui montrerait d'abord les jours passés) — l'utilisateur
                        // scrolle vers le haut seulement s'il veut revoir les
                        // épisodes déjà diffusés.
                        .onChange(of: viewModel.items) {
                            anchorToToday()
                        }
                        .onAppear {
                            anchorToToday()
                        }
                        // Dans un LazyVStack, les sections au-dessus d'"Aujourd'hui"
                        // n'ont que des hauteurs estimées au premier passage : la
                        // hauteur du contenu change pendant qu'elles sont mesurées.
                        // Tant que l'utilisateur n'a pas touché à la liste, on
                        // revise "Aujourd'hui" à chaque changement, au lieu de
                        // deviner un délai (ancien Task.sleep de 250 ms).
                        .onScrollGeometryChange(for: CGFloat.self) { geometry in
                            geometry.contentSize.height
                        } action: { _, _ in
                            if isAnchoredToToday {
                                scrollToToday()
                            }
                        }
                        .onScrollPhaseChange { _, phase in
                            if phase == .interacting {
                                isAnchoredToToday = false
                            }
                            // Après un deuxième toucher sur l'onglet : iOS fait remonter
                            // la liste tout en haut. Une fois ce défilement terminé, on
                            // la ramène sur « Aujourd'hui ».
                            if phase == .idle, returnsToTodayWhenIdle {
                                returnsToTodayWhenIdle = false
                                withAnimation {
                                    scrollToToday()
                                }
                            }
                        }
                        .onChange(of: viewModel.scrollToTodayRequests) {
                            returnsToTodayWhenIdle = true
                            withAnimation {
                                scrollToToday()
                            }
                        }
                        // Le cache peut retarder la prise en compte d'un nouvel épisode ou d'un cache vidé
                        // manuellement (voir Settings) — ce geste permet de
                        // forcer une revérification sans redémarrer l'app.
                        .refreshable {
                            await viewModel.refresh(showIDs: followedShowsStore.followedShowIDs)
                        }
                        .toolbar {
                            // Retour manuel à "Aujourd'hui" — utile après avoir
                            // scrollé loin dans les jours passés ou à venir,
                            // sans devoir tout re-scroller à la main.
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    withAnimation {
                                        scrollToToday()
                                    }
                                } label: {
                                    Text("Today")
                                }
                            }
                        }
                }
            }
            .navigationTitle("Schedule")
            .presentsShowDetailSheet(tmdbID: $selectedTMDBID)
            .settingsToolbarItem()
        }
    }

    private func scrollToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        scrollPosition.scrollTo(id: today, anchor: .top)
    }

    /// Vise "Aujourd'hui" et le garde en vue pendant la mise en page (voir
    /// onScrollGeometryChange), jusqu'au premier geste de l'utilisateur.
    private func anchorToToday() {
        isAnchoredToToday = true
        scrollToToday()
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
        // localAirDay : une date seule (sans heure) garde son jour, au lieu de
        // tomber la veille une fois convertie de minuit UTC à l'heure de Montréal.
        var itemsByDay = Dictionary(grouping: viewModel.items) { item in
            item.episode.localAirDay(in: calendar) ?? calendar.startOfDay(for: .distantFuture)
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
                let earliestDate = seasonItems.compactMap { $0.episode.airDate }.min()
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
        var isToday: Bool { Calendar.current.isDateInToday(day) }

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

            // Au-delà d'une semaine, une date complète ici ferait doublon
            // avec celle déjà affichée à droite (voir ScheduleSectionHeader) —
            // "Dans N jours" reste utile sans répéter l'info.
            if daysFromToday > 6 {
                return String(localized: "In \(daysFromToday) days")
            }

            // Cas résiduel (passé au-delà d'hier) : borné à recentlyAiredWindow
            // (7 jours), donc daysFromToday ne descend jamais en dessous de -7.
            return String(localized: "\(-daysFromToday) days ago")
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

/// En-tête de jour : jour à gauche ("Demain"), date complète à droite
/// ("21 juil. 2026") — repris de l'ancienne version de tvQ (tvQ-legacy).
///
/// Affiché comme en-tête d'un GroupedCard : chaque jour est ainsi un bloc
/// visuellement délimité de bout en bout (même vocabulaire que les autres
/// regroupements de l'app), plutôt qu'un simple libellé flottant au-dessus
/// de lignes. "Aujourd'hui" reçoit en plus le contour d'accent du
/// GroupedCard (isHighlighted) puisque c'est le point d'ancrage du scroll
/// initial (voir ScheduleView.scrollToToday).
private struct ScheduleSectionHeader: View {
    let section: ScheduleView.DaySection

    var body: some View {
        HStack {
            Text(section.title)
                .font(.subheadline.weight(.bold))
            Spacer()
            Text(section.day, format: .dateTime.day().month(.abbreviated).year())
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(section.isToday ? Color.emphasis : .secondary)
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

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.episodeNumbers, id: \.self) { episodeNumber in
                        HStack(spacing: 8) {
                            EpisodeTag(
                                text: Episode.code(season: group.seasonNumber, episode: episodeNumber),
                                style: .episode
                            )
                            if episodeNumber == 1 {
                                EpisodeTag(text: String(localized: "Premiere"), style: .premiere)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if hasAlreadyAired {
                Text("Aired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Agit sur toute la série : ses autres lignes changent aussi.
                NotificationBell(showID: group.show.id)
                    .padding(.top, -10)
            }
        }
        // Sans ça, avec .buttonStyle(.plain), seuls les pixels réellement dessinés
        // (affiche, textes, tags) captent le tap : le Spacer et les vides restent
        // inertes. Rectangle() rend toute la ligne cliquable.
        .contentShape(Rectangle())
        .opacity(shouldDim ? 0.6 : 1)
    }
}

/// Numéro d'épisode / repère "Premiere".
///
/// Style "glass" (choisi le 2026-08-09 après comparaison avec d'autres looks :
/// néon, glossy, métallique, minimaliste) : fond `.ultraThinMaterial`, contour
/// teinté. Le numéro d'épisode utilise Color.emphasis (même noir #101010 /
/// quasi-blanc adaptatif que le bloc "Aujourd'hui") ; "Premiere" utilise
/// l'accent (rose), seule info à mériter vraiment de ressortir.
private struct EpisodeTag: View {
    enum Style {
        case episode
        case premiere
    }

    let text: String
    let style: Style

    private var cornerRadius: CGFloat { 8 }

    /// Couleur du texte et du contour — .emphasis pour un numéro
    /// d'épisode ordinaire, l'accent (rose) pour "Premiere".
    private var tintColor: Color {
        switch style {
        case .episode: Color.emphasis
        case .premiere: Color.accentColor
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.4)
            .foregroundStyle(tintColor)
            // Largeur minimale : "S04E01", "S04E02"... ont le même nombre
            // de caractères mais un rendu à chasse variable (ex. "1" plus
            // étroit que "8") peut les décaler de 1-2pt d'une ligne à
            // l'autre quand elles sont empilées verticalement, ce qui se
            // remarque bien plus que dans l'ancien flow horizontal. minWidth
            // plutôt que width : certaines séries dépassent 99 épisodes
            // dans une saison (ex. animes à numérotation continue), et le
            // tag doit pouvoir s'élargir sans se faire couper dans ce cas.
            // Ne s'applique qu'au style .episode : "Premiere" n'a pas besoin
            // de s'aligner sur les numéros d'épisode.
            .frame(minWidth: style == .episode ? 52 : 0)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(tintColor.opacity(0.5), lineWidth: 1)
            }
    }
}

#Preview {
    ScheduleView()
        .environment(FollowedShowsStore())
        .environment(ScheduleViewModel())
}
