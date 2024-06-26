//
//  DefaultCreateMonthlyCalendarUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/23.
//

import Foundation

final class DefaultCreateMonthlyCalendarUseCase: CreateMonthlyCalendarUseCase {
    var calendar: Calendar
    
    init() {
        self.calendar = Calendar.current
    }
    
    func execute(date: Date) -> [Day] {
        
        let currentMonthStartIndex = (calendar.startDayOfTheWeek(from: date) + 7 - 1)%7
        let followingMonthStartIndex = currentMonthStartIndex + calendar.endDateOfMonth(for: date)
        let totalDaysCount = followingMonthStartIndex + ((followingMonthStartIndex % 7 == 0) ? 0 : (7 - followingMonthStartIndex % 7))
        let currentMonthStartDate = calendar.startDayOfMonth(date: date)
        
        var dayList = [Day]()
        
        (0..<totalDaysCount).forEach { day in
            var date: Date
            var state: MonthStateOfDay
            switch day {
            case (0..<currentMonthStartIndex):
                date = calendar.date(byAdding: DateComponents(day: -currentMonthStartIndex + day), to: currentMonthStartDate) ?? Date()
                state = .prev
            case (currentMonthStartIndex..<followingMonthStartIndex):
                date = calendar.date(byAdding: DateComponents(day: day - currentMonthStartIndex), to: currentMonthStartDate) ?? Date()
                state = .current
            case (followingMonthStartIndex..<totalDaysCount):
                date = calendar.date(byAdding: DateComponents(day: day - currentMonthStartIndex), to: currentMonthStartDate) ?? Date()
                state = .following
            default:
                fatalError()
            }
            
            dayList.append(Day(
                date: date,
                weekDay: WeekDay(rawValue: day%7)!,
                state: state
            ))
        }
        
        return dayList
    }
}
