import SwiftUI

struct ShowDetailView: View {
    /// Pays choisi par l'utilisateur ; nil = région de l'appareil (voir AppSettings).
    @AppStorage(AppSettings.Keys.watchProviderRegion) private var regionOverride: String?
    /// Largeur du plus long libellé de groupe (« Buy or Rent »…), pour aligner les pastilles.
    @State private var providerLabelWidth: CGFloat = 0
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel: ShowDetailViewModel
    /// Vrai une fois l'image d'en-tête sortie de l'écran : le titre réapparaît
    /// alors, en petit, dans la barre de navigation (il est déjà affiché en gros
    /// sur l'image tant qu'elle est visible).
    @State private var isHeroScrolledAway = false
    /// Résumé déplié (« more ») ou limité à 3 lignes.
    @State private var isOverviewExpanded = false

    /// Hauteur de l'image d'en-tête.
    nonisolated private static let heroHeight: CGFloat = 300


    /// La série affichée. Peut changer pendant que la vue reste à l'écran (sheet
    /// non modal) : le chargement suit via .task(id: tmdbID), plutôt que d'être
    /// figé par le view model créé une seule fois dans l'init (un @State n'est
    /// initialisé qu'à la première création de la vue).
    let tmdbID: Int

    init(tmdbID: Int) {
        self.tmdbID = tmdbID
        _viewModel = State(initialValue: ShowDetailViewModel(tmdbID: tmdbID))
    }

    var body: some View {
        Group {
            // Le ProgressView est le cas par défaut, pas seulement quand isLoading
            // est vrai : avant que .task ne démarre le chargement, aucune des
            // conditions n'est remplie. Un Group vide ne produit aucune vue, et
            // les modificateurs qui le suivent (.task, .navigationTitle,
            // .toolbar) n'ont alors rien à quoi s'accrocher : le chargement ne
            // démarrait jamais et le sheet restait vide.
            if let show = viewModel.show {
                content(for: show)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "wifi.slash",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: tmdbID) { viewModel.load(tmdbID: tmdbID) }
        .onChange(of: tmdbID) {
            isOverviewExpanded = false
        }
        .onContentLanguageChange { viewModel.reload() }
        .onChange(of: regionOverride) { viewModel.reloadWatchAvailability() }
        .navigationTitle(isHeroScrolledAway ? (viewModel.show?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for show: Show) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(for: show)

                // Hiérarchie inspirée de l'app TV d'Apple : une ligne de
                // métadonnées et le résumé d'abord, puis des sections titrées
                // (plutôt que des séparateurs), du plus utile au plus factuel.
                VStack(alignment: .leading, spacing: 10) {
                    if let metadata = metadataLine(for: show) {
                        Text(verbatim: metadata)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !show.overview.isEmpty {
                        overview(show.overview)
                    }
                }
                .padding(.horizontal)
                .padding(.top, -12)

                if let availability = viewModel.watchAvailability {
                    watchAvailabilitySection(availability)
                        .padding(.horizontal)
                }

                if !viewModel.sortedSeasonNumbers.isEmpty {
                    episodesSection
                        .padding(.horizontal)
                }

                aboutSection(for: show)
                    .padding(.horizontal)

                linksSection(for: show)
                    .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        // L'image passe sous la barre de navigation, comme dans l'app TV et
        // l'exemple Landmarks d'Apple : les boutons de la barre flottent en
        // Liquid Glass par-dessus, au lieu d'un bandeau blanc au-dessus.
        .ignoresSafeArea(edges: .top)
        // Fonction nonisolated plutôt qu'une closure : voir EvenGrid (la
        // transformation peut être appelée hors du fil principal).
        .onScrollGeometryChange(for: Bool.self, of: Self.isHeroScrolledAway(_:)) { _, scrolledAway in
            isHeroScrolledAway = scrolledAway
        }
    }

    /// Vrai une fois l'image d'en-tête presque sortie de l'écran.
    nonisolated private static func isHeroScrolledAway(_ geometry: ScrollGeometry) -> Bool {
        geometry.contentOffset.y + geometry.contentInsets.top > heroHeight - 80
    }

    // MARK: - En-tête de contenu

    /// « 2026 · Sci-Fi & Fantasy · Drama » : l'année (première diffusion, si la
    /// saison 1 est chargée) puis les genres. Le reste va dans About.
    private func metadataLine(for show: Show) -> String? {
        var parts: [String] = []
        if let firstAired {
            parts.append(firstAired.formatted(.dateTime.year()))
        }
        parts.append(contentsOf: show.genres)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Première diffusion connue : le plus ancien épisode daté de la saison 1.
    private var firstAired: Date? {
        viewModel.episodesBySeason[1]?.compactMap(\.airDate).min()
    }

    /// Résumé tronqué à 3 lignes, avec « more » pour le déplier (comme l'app TV).
    @ViewBuilder
    private func overview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.body)
                .lineLimit(isOverviewExpanded ? nil : 3)
            // Approximation volontaire : mesurer la troncature réelle demanderait
            // un second rendu caché ; au-delà de ~160 caractères, 3 lignes débordent.
            if text.count > 160 {
                Button(isOverviewExpanded ? "less" : "more") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOverviewExpanded.toggle()
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    // MARK: - Sections

    /// Titre de section, avec un contrôle optionnel à droite (pays, saison).
    private func sectionHeader<Trailing: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func aboutSection(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("About") { EmptyView() }

            VStack(spacing: 8) {
                LabeledContent("Status") { Text(show.status.displayName) }
                if let network = show.network {
                    LabeledContent("Network") { Text(verbatim: network) }
                }
                if let firstAired {
                    LabeledContent("First aired") { Text(firstAired, format: .dateTime.day().month().year()) }
                }
                if show.numberOfSeasons > 0 {
                    LabeledContent("Seasons") { Text(show.numberOfSeasons, format: .number) }
                }
                if let language = Locale.current.localizedString(forLanguageCode: show.originalLanguage) {
                    LabeledContent("Original language") { Text(verbatim: language.localizedCapitalized) }
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func linksSection(for show: Show) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Links") { EmptyView() }

            HStack(spacing: 20) {
                // imdbID est optionnel (voir Show.swift) : certaines séries
                // n'ont pas d'IMDB ID renseigné sur TMDB.
                if let imdbID = show.imdbID, let imdbURL = URL(string: "https://www.imdb.com/title/\(imdbID)/") {
                    // Logo officiel (trousse de marque IMDb, brand.imdb.com),
                    // versions noir/blanc adaptées au mode clair/sombre.
                    Link(destination: imdbURL) {
                        HStack(spacing: 6) {
                            Image("IMDbLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 16)
                                .accessibilityHidden(true)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("View on IMDb")
                }

                if let tmdbURL = URL(string: "https://www.themoviedb.org/tv/\(show.tmdbID)") {
                    Link(destination: tmdbURL) {
                        HStack(spacing: 4) {
                            Text(verbatim: "TMDB")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    // Texte seulement — pas les logos des diffuseurs/JustWatch, jugés pas assez
    // propres visuellement pour l'app.
    // Le lien JustWatch en fin de section reste discret (petite police, gris),
    // pas un deep-link vers l'app d'un diffuseur — TMDB n'en fournit pas.
    //
    // Quand TMDB n'a aucun diffuseur pour le pays choisi (providerNames vide),
    // on n'affiche pas juste rien : un CTA "Where to watch?" renvoie directement
    // vers JustWatch, mis à jour plus souvent que le cache TMDB (max 1×/24h).
    @ViewBuilder
    private func watchAvailabilitySection(_ availability: WatchAvailability) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Aucun diffuseur connu nulle part (ex. série toute récente) : le menu
            // n'offrirait que le pays courant. On le garde si un autre pays a été
            // choisi, pour pouvoir revenir à celui de l'appareil.
            let showsRegionMenu = !availability.availableRegions.isEmpty || regionOverride != nil
            sectionHeader("Where to Watch") {
                if showsRegionMenu {
                    regionMenu(availability)
                }
            }
            .padding(.bottom, 6)

            if availability.isEmpty {
                // Sous le titre « Where to Watch », le lien dit simplement où chercher.
                Link(destination: availability.justWatchURL) {
                    HStack(spacing: 4) {
                        Text("Search on JustWatch")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .font(.subheadline)


            } else {
                providerGroups(availability)
                    .padding(.vertical, 2)

                Link("via JustWatch", destination: availability.justWatchURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Diffuseurs regroupés par façon de regarder, en pastilles. Les libellés
    /// forment une colonne alignée sur le plus long (mesuré, donc juste dans
    /// toutes les langues) ; les pastilles passent à la ligne au besoin.
    private func providerGroups(_ availability: WatchAvailability) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            providerRow("Included", availability.included, prominent: true)
            providerRow("Free", availability.free, prominent: false)
            providerRow("Buy or Rent", availability.buyOrRent, prominent: false)
        }
    }

    @ViewBuilder
    private func providerRow(_ title: LocalizedStringKey, _ names: [String], prominent: Bool) -> some View {
        if !names.isEmpty {
            // .top plutôt que .firstTextBaseline : une Layout personnalisée n'expose
            // pas de ligne de base ; le décalage aligne le libellé sur la 1re rangée.
            HStack(alignment: .top, spacing: 10) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .padding(.top, 4)
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                        providerLabelWidth = max(providerLabelWidth, width)
                    }
                    .frame(minWidth: providerLabelWidth, alignment: .leading)
                FlowLayout {
                    ForEach(names, id: \.self) { name in
                        ProviderChip(name: name, prominent: prominent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Choix du pays des diffuseurs, là où il sert (plutôt que dans Settings).
    /// Par défaut la région de l'appareil ; le choix s'applique à toutes les fiches.
    private func regionMenu(_ availability: WatchAvailability) -> some View {
        let current = AppSettings.watchProviderRegion
        let regions = Set(availability.availableRegions).union([current])
            .sorted { AppSettings.regionDisplayName($0).localizedStandardCompare(AppSettings.regionDisplayName($1)) == .orderedAscending }

        return Menu {
            Button {
                regionOverride = nil
            } label: {
                let device = AppSettings.regionDisplayName(AppSettings.deviceRegion)
                if regionOverride == nil {
                    Label("Same as my device (\(device))", systemImage: "checkmark")
                } else {
                    Text("Same as my device (\(device))")
                }
            }
            Divider()
            ForEach(regions, id: \.self) { code in
                Button {
                    regionOverride = code
                } label: {
                    if regionOverride == code {
                        Label(AppSettings.regionDisplayName(code), systemImage: "checkmark")
                    } else {
                        Text(verbatim: AppSettings.regionDisplayName(code))
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(verbatim: availability.regionDisplayName)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
        }
        .font(.subheadline)
    }

    @ViewBuilder
    /// En-tête pleine largeur : l'image, le titre en gros sur un dégradé, et le
    /// badge de suivi.
    private func header(for show: Show) -> some View {
        RetryingAsyncImage(url: show.backdropURL ?? show.posterURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.secondary.opacity(0.2))
        }
        // maxWidth : l'en-tête prend toute la largeur offerte.
        // minWidth: 0 : indispensable. Sans minimum, le cadre garde la largeur
        // que réclame l'image en .fill pour couvrir 300 pt de haut (~533 pt
        // pour un backdrop 16:9), même dans un sheet plus étroit. L'en-tête
        // débordait alors, et tout le VStack s'élargissait avec lui (textes
        // coupés sur les bords). Même réglage que LandmarkDetailView d'Apple.
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: Self.heroHeight)
        .clipped()
        // Prolonge l'image, étirée et floutée, sous les barres latérales (ex.
        // la barre verticale d'un sheet sur l'iPhone Duo) au lieu d'y laisser
        // du blanc. Même technique que l'exemple Landmarks d'Apple, et au même
        // endroit : avant les overlays, pour que seule l'image soit prolongée
        // (pas le dégradé, le titre ni le badge).
        .backgroundExtensionEffect()
        // Dégradé sous le titre pour qu'il reste lisible sur n'importe quelle
        // image.
        .overlay {
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: 12) {
                Text(show.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(radius: 4)

                Spacer(minLength: 0)

                // Même badge que sur les cartes (ShowCardView). Hors de la barre
                // d'outils : les éléments de barre sont hébergés par UIKit et
                // reconstruits à chaque changement d'état, ce qui empêchait
                // l'animation du symbole (transition + rebond) de se jouer. En
                // bas de l'image plutôt qu'en haut : le haut passe maintenant
                // sous la barre de navigation.
                NotificationBell(showID: show.id, style: .badge)

                FollowBadge(
                    isFollowed: followedShowsStore.isFollowing(show.id),
                    action: { followedShowsStore.toggle(showID: show.id) }
                )
            }
            .padding()
        }
    }

    /// Une ligne repliable par saison (la saison ancienne se charge à l'ouverture).
    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Episodes") { EmptyView() }

            ForEach(viewModel.sortedSeasonNumbers, id: \.self) { seasonNumber in
                DisclosureGroup("Season \(seasonNumber)") {
                    if let episodes = viewModel.episodesBySeason[seasonNumber] {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber })) { episode in
                                EpisodeRow(episode: episode)
                                Divider()
                            }
                        }
                    } else if viewModel.failedSeasons.contains(seasonNumber) {
                        Button("Couldn't load this season. Try again.") {
                            viewModel.loadSeason(seasonNumber)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    } else {
                        // Saison ancienne : le contenu n'apparaît qu'à l'ouverture,
                        // c'est donc là qu'on la charge.
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .task { viewModel.loadSeason(seasonNumber) }
                    }
                }
            }
        }
    }
}

private struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(episode.episodeNumber). \(episode.title)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let date = episode.airDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !episode.overview.isEmpty {
                Text(episode.overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}

private extension ShowStatus {
    var displayName: LocalizedStringKey {
        switch self {
        case .running: "Running"
        case .ended: "Ended"
        case .upcoming: "Upcoming"
        case .unknown: "Unknown status"
        }
    }
}

#Preview {
    NavigationStack {
        ShowDetailView(tmdbID: 1399)
    }
    .environment(FollowedShowsStore())
}

/// Pastille d'un diffuseur. « Inclus » en couleur d'accent : l'œil va d'abord
/// à ce que l'utilisateur peut regarder sans rien payer de plus.
private struct ProviderChip: View {
    let name: String
    let prominent: Bool

    var body: some View {
        Text(verbatim: name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .background(
                prominent ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.fill.tertiary),
                in: Capsule()
            )
    }
}
