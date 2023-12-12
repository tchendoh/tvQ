//
//  DetailScreen.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-06.
//

import SwiftUI
import CachedAsyncImage

struct DetailScreen: View {
    @Environment(ViewModel.self) private var vm: ViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager
    @Environment(\.colorScheme) private var scheme
    
    var tvId: TVId
    var temporaryPoster: Image?
    @State private var tv: FullSingleTVResponse?
    @State private var tvUser: TVUser?
    
    var body: some View {
        ScrollView {
            if let tv {
                VStack (spacing: 0) {
                    // MARK: Main image
                    tvImage
                        .overlay {
                            let color = scheme == .dark ? Color.black : Color.white
                            LinearGradient(colors: [
                                .clear,
                                .clear,
                                .clear,
                                color.opacity(0.1),
                                color.opacity(0.5),
                                color.opacity(0.9),
                                color,
                            ], startPoint: .top, endPoint: .bottom)
                            .clipped()
                        }
                        
                    VStack {
                        HStack {
                            VStack (alignment: .leading) {
                                Text(tv.originalName ?? "original name")
                                    .font(.largeTitle)
                                    .fontWeight(.heavy)
                                    .kerning(-1)
                                if let tagline = tv.tagline {
                                    Text(tagline)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                        .italic()
                                }
                            }
                            Spacer()
                            if let genres = tv.genres {
                                VStack (alignment: .trailing) {
                                    ForEach(genres) { genre in
                                        Text(genre.name ?? "")
                                            .font(.caption)
                                    }
                                }
                            }
                            
                        }
                        
                        // MARK: Overview
                        if let overview = tv.overview {
                            HStack {
                                Text(overview)
                            }
                            .padding(.vertical)
                            
                        }
                        // MARK: Casting Carousel
                        if let cast = tv.aggregateCredits?.cast {
                            CastCarousel(cast: cast, castSize: 3)
                        }
                        
                        // MARK: JustWatch providers
                        if let tvUser {
                            if let results = tv.watchProviders?.results {
                                ProvidersView(userCountry: tvUser.country, providers: results)
                                
                            }
                        }
                        // MARK: IMDB link
                        if let imdb = tv.externalIds?.imdbID {
                            Link(destination: URL(string: "https://www.imdb.com/title/\(imdb)/")!) {
                                Image("imdbGold")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 70)
                            }
                            
                        }
                        
                    }
                    .padding(.horizontal)
                    .offset(y: -100)
                }
            }
            
        }
        .task {
            Task {
                tv = try await vm.fetchFullSingleTV(tvId: tvId)
                if let userId = authManager.user?.uid {
                    tvUser = try await vm.fetchUser(userId: userId)
                }
                
            }
        }
        .ignoresSafeArea(.all)
        
    }
    
    
    var tvImage: some View {
        CachedAsyncImage(url: URL(string: getImageURL())) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 400)
                
            } else if phase.error != nil {
                Color.red
                    .opacity(0.3)
            } else {
                if let temporaryPoster {
                    temporaryPoster
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 400)
                    
                } else {
                    Color.gray
                        .opacity(0.3)
                }
            }
        }
    }
    
    func getImageURL() -> String {
        guard let posterPath = tv?.posterPath else { return "" }
        let filePath = posterPath
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.BackdropSize.w1280
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
}

//#Preview {
//    DetailScreen(tvId: 1409)
//        .environment(ViewModel())
//}
