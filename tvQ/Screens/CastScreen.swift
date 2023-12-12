//
//  CastScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-31.
//

import SwiftUI

struct CastScreen: View {
    var cast: [Cast]
    @State var searchTerm: String = ""
    @State private var selectedPerson: Cast?
    @State private var showPersonSheet: Bool = false
    @State var temporaryImage: Image?
    
    let columns = [
        GridItem(.adaptive(minimum: 110))
    ]
    
    var filteredCast: [Cast] {
        guard !searchTerm.isEmpty else { return cast }
        var list: [Cast] = []
        for person in cast {
            if let personName = person.name {
                if personName.localizedCaseInsensitiveContains(searchTerm) {
                    list.append(person)
                    break
                }
            }
            
            for role in person.roles ?? [] {
                if let characterName = role.character {
                    if characterName.localizedCaseInsensitiveContains(searchTerm) {
                        list.append(person)
                        break
                    }
                }
            }
        }
        return list
        
    }
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach (filteredCast) { person in
                    PersonCardView(person: person, selectedPerson: $selectedPerson, showPersonSheet: $showPersonSheet, temporaryImage: $temporaryImage)
                }
            }
        }
        .searchable(text: $searchTerm, placement: .automatic, prompt: "Search")
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .sheet(isPresented: $showPersonSheet) {
            PersonScreen(selectedPerson: $selectedPerson, showPersonSheet: $showPersonSheet, temporaryImage: $temporaryImage)
                .presentationDetents([.large])
                .presentationCornerRadius(25)
        }
    }
}

//#Preview {
//    CastScreen()
//}
