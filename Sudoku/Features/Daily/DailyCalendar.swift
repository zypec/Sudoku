//
//  DailyCalendar.swift
//  Sudoku
//

import Foundation

/// Dates and daily puzzle days (`DailyPuzzle`), in the player's calendar. A day is the calendar date
/// the player sees, so a puzzle belongs to the same date everywhere, whatever the time zone.
enum DailyCalendar {
    /// A fixed calendar to count days in: only the year, month and day of a date are taken from the
    /// player's own calendar.
    private static let counting: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let start = counting.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast

    static func day(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let same = counting.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) else { return 0 }
        return counting.dateComponents([.day], from: start, to: same).day ?? 0
    }

    static func today(calendar: Calendar = .current) -> Int {
        day(of: .now, calendar: calendar)
    }

    /// Noon of the day in the player's calendar: a date that is safely inside it.
    static func date(ofDay day: Int, calendar: Calendar = .current) -> Date {
        guard let same = counting.date(byAdding: .day, value: day, to: start) else { return .now }
        let parts = counting.dateComponents([.year, .month, .day], from: same)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? .now
    }
}
