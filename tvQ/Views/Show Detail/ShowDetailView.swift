import SwiftUI

struct ShowDetailView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel: ShowDetailViewModel
    /// Vrai une fois l'image d'en-tête sortie de l'écran : le titre réapparaît
    /// alors, en petit, dans la barre de navigation (il est déjà affiché en gros
    /// sur l'image tant qu'elle est visible).
    @State private var isHeroScrolledAway = false

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
        .onContentLanguageChange { viewModel.reload() }
        .navigationTitle(isHeroScrolledAway ? (viewModel.show?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(for show: Show) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: show)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(show.status.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.15), in: Capsule())

                        if let network = show.network {
                            Text(network)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if !show.genres.isEmpty {
                        Text(show.genres.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !show.overview.isEmpty {
                        Text(show.overview)
                            .font(.body)
                            .padding(.top, 4)
                    }

                    // imdbID est optionnel (voir Show.swift) : certaines séries
                    // n'ont pas d'IMDB ID renseigné sur TMDB, auquel cas il n'y a
                    // simplement pas de lien à montrer.
                    if let imdbID = show.imdbID, let imdbURL = URL(string: "https://www.imdb.com/title/\(imdbID)/") {
                        // Logo officiel (trousse de marque IMDb, brand.imdb.com) plutôt
                        // qu'une icône générique — versions noir/blanc en Assets.xcassets
                        // (IMDbLogo), adaptées automatiquement au mode clair/sombre.
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
                        .padding(.top, 4)
                    }

                    if let availability = viewModel.watchAvailability {
                        watchAvailabilitySection(availability)
                    }
                }
                .padding(.horizontal)

                if !viewModel.episodesBySeason.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    seasonsSection
                }
            }
            .padding(.bottom)
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
            if availability.isEmpty {
                Link(destination: availability.justWatchURL) {
                    HStack(spacing: 4) {
                        Text("Where to watch?")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .font(.subheadline)

                Text("via JustWatch")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Watch (\(availability.regionDisplayName)) on \(availability.providerNames.joined(separator: ", "))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Link("via JustWatch", destination: availability.justWatchURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
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

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.headline)
                .padding(.horizontal)

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
                .padding(.horizontal)
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
