//
//  TimelineScreen.swift
//  BingeQ
//
//  Created by Eric Chandonnet on 2023-12-09.
//

import SwiftUI
import FirebaseAuth

struct TimelineScreen: View {
    @Environment(ViewModel.self) private var vm: ViewModel
    @Environment(AuthManager.self) private var authManager: AuthManager
    @Binding var navManager: NavManager
    @State private var timeline: [TimelineDay] = []
    @State private var userList: [Int] = []
    @State private var scrollPosition: UUID?
    @State private var isLoaded: Bool = false
    @State var thumbnailCache: [Int:Image?] = [:]
    let calendar = Calendar.current
    
    var body: some View {
        NavigationStack(path: $navManager.timelineStack) {
            if timeline.isEmpty && isLoaded {
                VStack {
                    Spacer()
                    ContentUnavailableView(
                        "Nothing here yet. Follow some tv series!",
                        systemImage: "tray"
                    )
                    .opacity(0.6)
                    Spacer()
                }
                .navigationTitle("Timeline")
                
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(timeline) { day in
                            TimelineDayView(day: day, thumbnailCache: $thumbnailCache)
                                .id(day.id)
                        }
                        .navigationDestination(for: Int.self) { tvId in
                            DetailScreen(tvId: tvId, temporaryPoster: thumbnailCache[tvId] ?? nil)
                        }
                    }
                }
                .navigationTitle("Timeline")
                .scrollPosition(id: $scrollPosition)
            }
        }
        .task {
            Task {
                if let userId = authManager.user?.uid {
                    timeline = try await vm.populateTimeline(userId: userId)
                    scrollPosition = getScrollPosition()
                }
                isLoaded = true
            }
        }
    }
    
    func getScrollPosition() -> UUID {
        let tupleDays = timeline.map { ($0.date, $0.id) }
        let components = calendar.dateComponents([.year, .month, .day], from: Date.now)
        let midnight = calendar.date(from: components)!
        var lastDay: Date?
        for day in tupleDays {
            if let lastDay {
                if lastDay < midnight && day.0 >= midnight {
                    return day.1
                }
            }
            lastDay = day.0
        }
        return UUID()
    }
}

//#Preview {
//    TimelineScreen()
//        .environment(ViewModel(apiService: APIManager(), dataService: DataManager()))
//        .environment(AuthManager.shared)
//}
