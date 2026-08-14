import SwiftUI

/// Horaire de diffusion : épisodes récemment diffusés (jusqu'à 7 jours, voir
/// RemoteScheduleRepository.recentlyAiredWindow) et à venir, toutes séries
/// suivies confondues, groupés par jour.
struct ScheduleView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel = ScheduleViewModel()
    @State private var showingDiagnostics = false

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
                                                    NavigationLink(value: group.show) {
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
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
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
                        // Le cache (12h local, 24h Firestore) peut retarder la
                        // prise en compte d'un nouvel épisode ou d'un cache vidé
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
                                        scrollToToday(using: proxy)
                                    }
                                } label: {
                                    Text("Today")
                                }
                            }
                            // Diagnostic de performance du dernier chargement
                            // (voir ScheduleLoadMetrics) — utile pour vérifier
                            // que le cache fonctionne comme prévu sans sortir
                            // Instruments. Masqué s'il n'y a encore rien à montrer.
                            if viewModel.lastLoadMetrics != nil {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        showingDiagnostics = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                    }
                                    .popover(isPresented: $showingDiagnostics) {
                                        if let metrics = viewModel.lastLoadMetrics {
                                            ScheduleDiagnosticsView(metrics: metrics)
                                        }
                                    }
                                }
                            }
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

                // Reprise de l'ancienne version de tvQ (tvQ-legacy) : un tag par
                // épisode plutôt qu'un résumé texte ("Saison X — N épisodes") —
                // reste lisible même quand une saison complète sort le même jour.
                // Une ligne par épisode (plutôt qu'un flow horizontal qui wrap) :
                // "Premiere" reste collé au tag d'épisode correspondant, pas
                // poussé à l'autre bout de la ligne.
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.episodeNumbers, id: \.self) { episodeNumber in
                        HStack(spacing: 8) {
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
            }

            Spacer(minLength: 0)

            if hasAlreadyAired {
                Text("Aired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(shouldDim ? 0.6 : 1)
    }
}

/// Numéro d'épisode / repère "Premiere".
///
/// Style "glass" (choisi le 2026-08-09 après comparaison dans TagStyleLabView,
/// voir Debug/TagStyleLabView.swift pour les autres looks essayés — néon,
/// glossy, métallique, minimaliste) : fond `.ultraThinMaterial`, contour
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

/// Résumé du dernier chargement de l'horaire — temps par étape et d'où
/// viennent les données (cache local / Firestore partagé / API fraîche).
/// Voir ScheduleLoadMetrics ; accessible via le bouton "i" de ScheduleView.
private struct ScheduleDiagnosticsView: View {
    let metrics: ScheduleLoadMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last load")
                .font(.headline)

            row(
                label: "Shows",
                duration: metrics.showsDuration,
                tiers: metrics.showsByTier
            )
            row(
                label: "Episodes",
                duration: metrics.episodesDuration,
                tiers: metrics.episodesByTier
            )

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.semibold)
                Spacer()
                Text(metrics.totalDuration.diagnosticDescription)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .frame(minWidth: 260)
        .presentationCompactAdaptation(.popover)
    }

    private func row(label: LocalizedStringKey, duration: Duration, tiers: ScheduleLoadMetrics.TierBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(duration.diagnosticDescription)
                    .foregroundStyle(.secondary)
            }
            if tiers.total > 0 {
                Text("\(tiers.local) local · \(tiers.shared) shared · \(tiers.remote) fresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environment(FollowedShowsStore())
}
