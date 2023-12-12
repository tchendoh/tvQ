//
//  TimelineTVView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-17.
//

import SwiftUI
import CachedAsyncImage

struct TimelineTVView: View {
    var tv: TimelineTV
    private let episodeTagColor = "episodeTagGray"
    @Binding var thumbnailCache: [Int:Image?]

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink(value: tv.tvId) {
                tvImage
                    .frame(minWidth: 80, maxWidth: 80, minHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(4)
            }
            
            VStack (alignment: .leading, spacing: 0) {
                Text("\(tv.originalName)")
                    .font(.system(size: 16))
                    .fontWeight(.heavy)
                VStack (alignment: .leading, spacing: 2) {
                    let totalEpisodes = tv.timelineEpisodes.count
                    ForEach(tv.timelineEpisodes) { episode in
                        HStack {
                            HStack {
                                EpisodeNumberView(episodeNumber: episode.episodeNumber, seasonNumber: episode.seasonNumber)
                            }
                            .background(getEpisodeTagColor(numberOfEpisodes: totalEpisodes))
                            .clipShape(RoundedRectangle(cornerRadius: 6.0))
                            .shadow(color: getEpisodeTagColor(numberOfEpisodes: totalEpisodes), radius: totalEpisodes > 3 ? 10 : 0)
                            
                            if episode.episodeNumber == 1 {
                                HStack {
                                    Text("PREMIERE")
                                        .font(.system(size: 12))
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                }
                                .background(Color.pink)
                                .clipShape(RoundedRectangle(cornerRadius: 6.0))
                                .shadow(color: Color.pink, radius: 5)
                            }
                        }
                    }
                }
                .padding(.top, 4)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
            Spacer()
        }
    }
    var tvImage: some View {
        CachedAsyncImage(url: URL(string: getImageURL())) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        thumbnailCache[tv.tvId] = image
                    }
                
            } else if phase.error != nil {
                Color.red
            } else {
                Color.pink.opacity(0.1)
            }
        }
    }
    
    /// In order to generate a fully working image URL, you'll need a base_url, a file_size and a file_path.
    private func getImageURL() -> String {
        guard let filePath = tv.posterPath else { return "" }
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.PosterSize.w154
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
    
    private func getEpisodeTagColor(numberOfEpisodes: Int) -> Color {
        var episodeTagColor = Color("episodeTagGray")
        if numberOfEpisodes > 3 {
            episodeTagColor = Color("episodeTagGreen")
        } else if numberOfEpisodes > 1 {
            episodeTagColor = Color("episodeTagYellow")
        }
        return episodeTagColor

    }

}

//#Preview {
//    TimelineTVView(tv: TimelineTV()
//}

