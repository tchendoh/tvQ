//
//  CardView.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-04.
//

import SwiftUI
import CachedAsyncImage

struct CardView: View {
    var tvItem: TVUser.TVItem
    @Binding var thumbnailCache: [Int:Image?]

    let cardWidth: CGFloat = 110
    
    var body: some View {
        VStack {
            NavigationLink(value: tvItem.tvId) {
                tvImage
                    .frame(width: cardWidth, height: cardWidth * 3/2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        FollowButton(tvItem: tvItem)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: 2, y: -2)
                    }
            }

            HStack {
                VStack (alignment: .center) {
                    Text("\(tvItem.originalName)")
                        .font(.system(size: 14))
                        .kerning(-1)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .frame(width: cardWidth)
        }
    }
    
    var tvImage: some View {
        CachedAsyncImage(url: URL(string: getImageURL())) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .onAppear {
                        thumbnailCache[tvItem.tvId] = image
                    }
                
            } else if phase.error != nil {
                Color.red
            } else {
                Color.pink.opacity(0.1)
                
            }
        }
    }
    
    /// In order to generate a fully working image URL, you'll need a base_url, a file_size and a file_path.
    func getImageURL() -> String {
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.PosterSize.w154
        let filePath = tvItem.posterPath
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
}

//#Preview {
//    SearchScreen()
//        .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
//        .environment(AuthManager.shared)
//}
