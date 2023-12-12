//
//  TimelineDayView.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-17.
//

import SwiftUI

struct TimelineDayView: View {
    var day: TimelineDay
    @Binding var thumbnailCache: [Int:Image?]

    var body: some View {
        VStack (spacing: 0) {
            HStack {
                TimelineDate(date: day.date)
                    .padding(.bottom, 3)
                Spacer()
            }
            .padding(.leading)
            .padding(.trailing, 10)
            .padding(.bottom, 3)
            .padding(.top, 25)
            
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(Color("timelineDayContainer"))
                        .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 0)
                    VStack(spacing: 0) {
                        ForEach(day.timelineTVs) { tv in
                            TimelineTVView(tv: tv, thumbnailCache: $thumbnailCache)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

//#Preview {
//    TimelineDayView(day: TimelineDay(date: Date.now, timelineTVs: []))
//}


