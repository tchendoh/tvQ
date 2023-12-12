//
//  TimelineDate.swift
//  tvQ
//
//  Created by Eric Chandonnet on 2023-12-18.
//

import SwiftUI

struct TimelineDate: View {
    var date: Date
    let calendar = Calendar.current
    let nextWeek = Date.now.addingTimeInterval(86400 * 7)
        
    var body: some View {
        HStack {
            HStack {
                if calendar.isDateInToday(date) {
                    Text("Today")
                } else if calendar.isDateInYesterday(date) {
                    Text("Yesterday")
                } else if calendar.isDateInTomorrow(date) {
                    Text("Tomorrow")
                } else if date < nextWeek && date > Date.now{
                    Text("\(dayOfWeekString(from: date)) ")
                } else if date > Date.now {
                    Text("In \(numberOfDaysUntil(endDate: date)) days")
                }
            }
            .font(.system(size: 14))
            .fontWeight(.bold)
            Spacer()
            Text(normalDate(from: date))
                .font(.system(size: 14))
        }
        
    }
    
    func dayOfWeekString(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)
    }

    func normalDate(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }

    func numberOfDaysUntil(endDate: Date) -> Int {
        let calendar = Calendar.current
        let todayMidnight = calendar.startOfDay(for: Date())
        let daysBetween = calendar.dateComponents([.day], from: todayMidnight, to: endDate).day!
        return daysBetween
    }
}

//#Preview {
//    // nextMonth Date.now.addingTimeInterval(60 * 24 * 60 * 60)
//    // today
//    TimelineDate(date: Date.now.addingTimeInterval(86400 * 2))
//}
