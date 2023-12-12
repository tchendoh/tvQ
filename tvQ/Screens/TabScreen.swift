//
//  TabScreen.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-27.
//

import SwiftUI

struct TabScreen: View {
    @Environment(AuthManager.self) private var authManager: AuthManager
    @Environment(ViewModel.self) private var vm: ViewModel
    @State var navManager = NavManager()
    @State var activeTab = Tab.userList

    var body: some View {
        TabView(selection: $activeTab.onUpdate {
            navManager.tabClicked(activeTab)
        }) {
            UserListScreen(navManager: $navManager)
                .tabItem {
                    Label("Your list", systemImage: "square.grid.3x3.square")
                }
                .tag(Tab.userList)
            
            SearchScreen(navManager: $navManager)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)
            
            TimelineScreen(navManager: $navManager)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(Tab.timeline)
            
            Text("rankings")
                .tabItem {
                    Label("Ranking", systemImage: "chart.bar.xaxis.ascending")
                }
                .tag(Tab.timeline)
            
            SettingsScreen(navManager: $navManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
}

//#Preview {
//    TabScreen()
//}
