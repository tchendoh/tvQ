//
//  ProviderView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-03.
//

import SwiftUI
import CachedAsyncImage

struct ProviderView: View {
    var provider: FullSingleTVResponse.WatchProvider.Result.CountryResult.Flatrate
    let cardWidth: CGFloat = 92
    var body: some View {
        VStack {
            tvImage
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: cardWidth)
            
            HStack {
                VStack (alignment: .center) {
                    Text("\(provider.providerName ?? "")")
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
                    .aspectRatio(contentMode: .fit)
                
            } else if phase.error != nil {
                Color.red
            } else {
                Color.pink.opacity(0.2)
                
            }
        }
    }
    
    /// In order to generate a fully working image URL, you'll need a base_url, a file_size and a file_path.
    func getImageURL() -> String {
        guard let filePath = provider.logoPath else {
            return ""
        }
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.LogoSize.w92
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
}

//#Preview {
//    ProviderView()
//}
