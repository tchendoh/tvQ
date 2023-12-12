//
//  PersonCardView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-31.
//

import SwiftUI
import CachedAsyncImage

struct PersonCardView: View {
    var person: Cast
    @Binding var selectedPerson: Cast?
    @Binding var showPersonSheet: Bool
    @Binding var temporaryImage: Image?
    @State private var thumbnailImage: Image?

    let cardWidth: CGFloat = 110


    var body: some View {
        VStack {
            personImage
                .frame(width: cardWidth, height: cardWidth * 3/2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    temporaryImage = thumbnailImage
                    selectedPerson = person
                    showPersonSheet = true
                }

            HStack {
                VStack (alignment: .center) {
                    if let roles = person.roles {
                        ForEach(roles) { role in
                            Text(role.character ?? "")
                                .font(.system(size: 14))
                                .kerning(-1)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    if let name = person.name {
                        Text(name)
                            .font(.system(size: 14))
                            .kerning(-1)
                            .multilineTextAlignment(.center)

                    }
                    Spacer()
                }
                .frame(width: cardWidth)
            }
            .frame(width: cardWidth)            
        }

    }
    var personImage: some View {
        CachedAsyncImage(url: URL(string: getImageURL())) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .onAppear {
                        thumbnailImage = image
                    }

            } else if phase.error != nil {
                Color.red
            } else {
                Color.pink.opacity(0.1)
                
            }
        }
    }
    
    func getImageURL() -> String {
        guard let filePath = person.profilePath else {
            return ""
        }
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.ProfileSize.w185
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
}

//#Preview {
//    PersonCardView()
//}
