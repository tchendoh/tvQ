import SwiftUI

struct ShowDetailView: View {
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

    @ViewBuilder
    private func header(for show: Show) -> some View {
        AsyncImage(url: show.backdropURL ?? show.posterURL) { image in
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
}
