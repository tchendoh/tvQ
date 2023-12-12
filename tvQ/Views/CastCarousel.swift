//
//  CastCarousel.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-06.
//

import SwiftUI

struct CastCarousel: View {
    @Environment(\.colorScheme) private var scheme
    var cast: [Cast]
    var castSize: Int
    @State private var selectedPerson: Cast?
    @State private var showPersonSheet: Bool = false
    @State var temporaryImage: Image?
    
    var filteredCast: [Cast] {
        return Array(cast.prefix(4))
    }
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                ForEach (filteredCast) { person in
                    PersonCardView(person: person, selectedPerson: $selectedPerson, showPersonSheet: $showPersonSheet, temporaryImage: $temporaryImage)
                }
                VStack {
                    NavigationLink(value: "CastScreen") {
                        VStack {
                            Spacer()
                            Text("All")
                            Spacer()
                        }
                        .frame(width: 110, height: 110 * 3/2)
                        .background(.pink.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .navigationDestination(for: String.self) { _ in
                        CastScreen(cast: cast)
                    }
                    Spacer()
                }
                
            }
        }
        .sheet(isPresented: $showPersonSheet) {
            PersonScreen(selectedPerson: $selectedPerson, showPersonSheet: $showPersonSheet, temporaryImage: $temporaryImage)
                .presentationDetents([.large])
                .presentationCornerRadius(25)
        }
    }
}

//#Preview {
//    CastCarousel()
//}
