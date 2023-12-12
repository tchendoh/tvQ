//
//  UserListScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-22.
//

import SwiftUI

struct UserListScreen: View {
    @Environment(ViewModel.self) private var vm: ViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager
    
    @Binding var navManager: NavManager
    @State private var userList: [TVUser.TVItem]?
    @State private var activeUserList: [TVUser.TVItem]?
    @State private var inactiveUserList: [TVUser.TVItem]?
    @State private var isLoaded: Bool = false
    @State var thumbnailCache: [Int:Image?] = [:]
    
    let columns = [
        GridItem(.adaptive(minimum: 110))
    ]
    
    var body: some View {
        
        NavigationStack(path: $navManager.userListStack) {
            if userList != nil && !(userList ?? []).isEmpty  {
                ScrollView {
                    VStack (spacing: 0) {
                        if let activeUserList, !activeUserList.isEmpty {
                            VStack (spacing: 0) {
                                HStack {
                                    Text("In progress")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                        .kerning(-1)
                                    Spacer()
                                }
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach (activeUserList) { tvItem in
                                        HStack {
                                            CardView(tvItem: tvItem, thumbnailCache: $thumbnailCache)
                                        }
                                    }
                                }
                                .frame(minHeight: 130)
                                .padding(.vertical)
                            }
                            .padding()
                        }
                        
                        if let inactiveUserList, !inactiveUserList.isEmpty {
                            VStack (spacing: 0) {
                                HStack {
                                    Text("Ended")
                                        .font(.system(size: 18))
                                        .fontWeight(.bold)
                                        .kerning(-1)
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach (inactiveUserList) { tvItem in
                                        HStack {
                                            CardView(tvItem: tvItem, thumbnailCache: $thumbnailCache)
                                        }
                                    }
                                }
                                .frame(minHeight: 130)
                                .padding(.vertical)

                            }
                            .padding()
                        }
                        
                    }
                    .navigationDestination(for: Int.self) { tvId in
                        DetailScreen(tvId: tvId, temporaryPoster: thumbnailCache[tvId] ?? nil)
                    }
                    .padding()
                }
                .navigationTitle("Your list")
            }
            else {
                if isLoaded {
                    VStack {
                        Spacer()
                        ContentUnavailableView(
                            "Nothing here yet. Follow some tv series!",
                            systemImage: "tray"
                        )
                        .opacity(0.6)
                        Spacer()
                    }
                    .navigationTitle("Your list")
                }
            }
            
        }
        .task {
            Task {
                if let userId = authManager.user?.uid {
                    userList = try await vm.fetchUserTVItems(userId: userId)
                    activeUserList = userList?.filter { $0.isActive }
                    inactiveUserList = userList?.filter { $0.isActive == false }
                    isLoaded = true
                }
                else {
                    print("No user while loading UserListScreen. No bueno.")
                }
            }
            
        }
    }
}

//#Preview {
//    NavigationStack {
//        UserListScreen()
//            .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
//            .environment(AuthManager.shared)
//    }
//}
