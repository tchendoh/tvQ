import SwiftUI

struct ShowDetailView: View {
    @Environment(FollowedShowsStore.self) private var followedShowsStore
    @State private var viewModel: ShowDetailViewModel

    init(tmdbID: Int) {
        _viewModel = State(initialValue: ShowDetailViewModel(tmdbID: tmdbID))
    }

    var body: some View {
        Group {
            if let show = viewModel.show {
                content(for: show)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "wifi.slash",
                    description: Text(errorMessage)
                )
            }
        }
        .task { viewModel.load() }
        .navigationTitle(viewModel.show?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Suivre/ne plus suivre directement depuis la fiche — jusqu'ici
            // seulement possible via le badge sur les grilles (Search, My Shows).
            if let show = viewModel.show {
                ToolbarItem(placement: .topBarTrailing) {
                    let isFollowing = followedShowsStore.isFollowing(show.id)
                    Button {
                        withAnimation(.spring) {
                            followedShowsStore.toggle(showID: show.id)
                        }
                    } label: {
                        // FollowIcon centralise icône + couleur, partagée avec
                        // FollowBadge dans ShowCardView (Search, My Shows).
                        Label {
                            Text(isFollowing ? "Following" : "Follow")
                        } icon: {
                            FollowIcon(isFollowing: isFollowing)
                        }
                    }
                    // Le bouton de toolbar en verre (iOS 26) teinte son glyphe
                    // lui-même et ignore le foregroundStyle interne de
                    // FollowIcon — il faut teinter le Button directement pour
                    // que la couleur voulue s'applique réellement ici.
                    .tint(FollowIcon.tintColor(isFollowing: isFollowing))
                }
            }
        }
    }

    @ViewBuilder
    private func content(for show: Show) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: show)

                VStack(alignment: .leading, spacing: 8) {
                    Text(show.title)
                        .font(.title2.bold())

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
            .padding(.vertical)
        }
    }

    // Texte seulement — pas les logos des diffuseurs/JustWatch, jugés pas assez
    // propres visuellement pour l'app (voir discussion, backlog "Où regarder").
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
    private func header(for show: Show) -> some View {
        RetryingAsyncImage(url: show.backdropURL ?? show.posterURL) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle().fill(.secondary.opacity(0.2))
        }
        .frame(height: 200)
        .clipped()
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.sortedSeasonNumbers, id: \.self) { seasonNumber in
                if let episodes = viewModel.episodesBySeason[seasonNumber] {
                    DisclosureGroup("Season \(seasonNumber)") {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(episodes.sorted(by: { $0.episodeNumber < $1.episodeNumber })) { episode in
                                EpisodeRow(episode: episode)
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal)
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
                if let date = episode.bestAvailableDate {
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
