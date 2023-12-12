//
//  PersonScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-31.
//

import SwiftUI
import CachedAsyncImage

struct PersonScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(ViewModel.self) private var vm: ViewModel

    @Binding var selectedPerson: Cast?
    @Binding var showPersonSheet: Bool
    @Binding var temporaryImage: Image?

    @State private var person: Person?

    @State private var isOffset: [Bool] = Array(repeating: true, count: 3)

    var body: some View {
        ScrollView {
            VStack {
                tvImage
                    .frame(minHeight: 400)
                    .onTapGesture {
                        Task {
                            showPersonSheet = false
                            try await Task.sleep(nanoseconds: 350_000_000)
                            selectedPerson = nil
                            temporaryImage = nil
                        }
                    }
                    .overlay {
                        let color = scheme == .dark ? Color.black : Color.white
                        LinearGradient(colors: [
                            .clear,
                            .clear,
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
                    .onAppear {
                        /// changer en fonction
                        var index = 0
                        withAnimation(.bouncy) {
                            isOffset[index] = false
                        }
                        var _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true){ t in
                            index += 1
                            if index >= isOffset.count {
                                t.invalidate()
                            } else {
                                withAnimation(.bouncy) {
                                    isOffset[index] = false
                                }
                            }
                        }
                    }
                
                if let person {
                    VStack {
                        HStack {
                            Text(person.name ?? "")
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .kerning(-1)
                                .offset(y: isOffset[0] ? 1000 : 0)
                            Spacer()
                            if let imdb = person.imdbID {
                                Link(destination: URL(string: "https://www.imdb.com/name/\(imdb)/")!) {
                                    Image("imdbGold")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 70)
                                }
                                .padding()
                                .offset(y: isOffset[1] ? 1000 : 0)
                            }

                        }
                        HStack {
                            Text(person.biography ?? "")
                                .offset(y: isOffset[2] ? 1000 : 0)
                        }
                    }
                    .padding(10)
                    .offset(y: -100)

                }
            }

        }
        .task {
            Task {
                if let personId = selectedPerson?.id {
                    person = try await vm.fetchPerson(personId: personId)
                }
            }
            
        }
    }
    
    var tvImage: some View {
        CachedAsyncImage(url: URL(string: getImageURL())) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                
            } else if phase.error != nil {
                Color.red
                    .opacity(0.3)
            } else {
                if let temporaryImage {
                    temporaryImage
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.gray
                        .opacity(0.3)
                }
            }
        }
    }
    
    func getImageURL() -> String {
        guard let filePath = selectedPerson?.profilePath else { return "" }
        let baseUrl = Constants.Tmdb.Image.BaseUrl.secure
        let fileSize = Constants.Tmdb.Image.ProfileSize.original
        return "\(baseUrl)\(fileSize)\(filePath)"
    }
}

//#Preview {
//    PersonScreen()
//}
