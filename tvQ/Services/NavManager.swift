//
//  NavManager.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2024-01-12.
//

import Foundation
import SwiftUI
import Observation

enum Tab {
    case userList, search, timeline, ranking, settings
}

@Observable
final class NavManager {
    private var currentTab = Tab.userList
    var userListStack = NavigationPath()
    var searchStack = NavigationPath()
    var timelineStack = NavigationPath()
    var rankingStack = NavigationPath()
    var settingsStack = NavigationPath()

    func tabClicked(_ tab: Tab) {
        if(tab == currentTab && currentTab == .userList) {
            userListStack.removeLast(userListStack.count)
        } else if(tab == currentTab && currentTab == .search) {
            searchStack.removeLast(searchStack.count)
        } else if(tab == currentTab && currentTab == .timeline) {
            timelineStack.removeLast(timelineStack.count)
        } else if(tab == currentTab && currentTab == .ranking) {
            rankingStack.removeLast(rankingStack.count)
        } else if(tab == currentTab && currentTab == .settings) {
            settingsStack.removeLast(settingsStack.count)
        }
        currentTab = tab
    }
    
}

