//
//  SearchScreen.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-01.
//

import SwiftUI

struct SearchScreen: View {
    @Environment(AuthManager.self) private var authManager: AuthManager
    @Environment(ViewModel.self) private var vm: ViewModel
    @State var query: String = ""
    @State private var results: [TVUser.TVItem] = []
    @State var thumbnailCache: [Int:Image?] = [:]

    let columns = [
        GridItem(.adaptive(minimum: 110))
    ]

    @Binding var navManager: NavManager

    var body: some View {
        NavigationStack(path: $navManager.searchStack) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach (results) { tvItem in
                        HStack {
                            CardView(tvItem: tvItem, thumbnailCache: $thumbnailCache)
                        }
                    }
                }
                .padding()
                .onChange(of: query) { oldValue, newValue in
                    if (!newValue.isEmpty && newValue.count > 2) {
                        Task {
                            do {
                                results = try await vm.search(query: newValue)
                            } catch {
                                throw(error)
                            }
                        }
                    }
                    else {
                        results = []
                    }
                }
            }
            .searchable(text: $query)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .navigationDestination(for: Int.self) { tvId in
                DetailScreen(tvId: tvId, temporaryPoster: thumbnailCache[tvId] ?? nil)
            }
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView.search
                        .opacity(0.6)
                }
            }
        }
    }
}

//#Preview {
//    NavigationStack {
//        SearchScreen()
//            .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
//            .environment(AuthManager.shared)
//    }
//}
