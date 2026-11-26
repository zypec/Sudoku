//
//  DailyPuzzleTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@Suite("Daily puzzle")
struct DailyPuzzleTests {
    @Test func aDayAlwaysHasTheSamePuzzle() throws {
        let first = try #require(DailyPuzzle.puzzle(forDay: 330))
        #expect(DailyPuzzle.puzzle(forDay: 330) == first)
        #expect(DailyPuzzle.puzzle(forDay: 331) != first)
        // Its code is a short one, so a daily puzzle can be shared like any other.
        #expect(PuzzleCode.code(for: first).count == 11)
        #expect(PuzzleCode.puzzle(from: PuzzleCode.code(for: first)) == first)
    }

    @Test func theWeekGoesFromEasyToExpert() {
        // Day 0 is Thursday, January 1, 2026; day 4 is the Monday after.
        let week = (4..<11).map(DailyPuzzle.difficulty(forDay:))
        #expect(week == [.easy, .easy, .medium, .medium, .hard, .hard, .expert])
        for day in 0..<14 {
            #expect(DailyPuzzle.puzzle(forDay: day)?.difficulty == DailyPuzzle.difficulty(forDay: day))
        }
    }

    @Test func aDateIsTheSameDayInEveryTimeZone() throws {
        var istanbul = Calendar(identifier: .gregorian)
        istanbul.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        let date = try #require(istanbul.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 23)))
        #expect(DailyCalendar.day(of: date, calendar: istanbul) == 329)
        // The same moment is still November 26 in Honolulu; the puzzle goes with the date shown.
        #expect(DailyCalendar.day(of: date, calendar: honolulu) == 329)
        let morning = try #require(honolulu.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 8)))
        #expect(DailyCalendar.day(of: morning, calendar: honolulu) == 330)
        #expect(DailyCalendar.day(of: DailyCalendar.date(ofDay: 330, calendar: honolulu), calendar: honolulu) == 330)
    }

    @Test func aStreakCountsDaysSolvedOnTheDay() {
        let streak = DailyStreak(solved: [(10, 10), (11, 11), (12, 12), (14, 14), (15, 15), (16, 17)])
        // Day 16 was solved late: it doesn't count.
        #expect(streak.solvedDays == [10, 11, 12, 14, 15])
        #expect(streak.best == 3)
        // Today still open: the streak of yesterday stands.
        #expect(streak.current(today: 16) == 2)
        #expect(streak.current(today: 15) == 2)
        // A whole day missed ends it.
        #expect(streak.current(today: 17) == 0)
        #expect(DailyStreak(solvedDays: []).current(today: 5) == 0)
    }

    /// The records the app keeps: solved daily games, by their day and the day they were finished.
    @Test func recordsMakeTheStreak() {
        let today = DailyCalendar.today()
        func record(day: Int, finishedOn: Int, solved: Bool = true) -> GameRecord {
            let result = GameResult(finishedAt: DailyCalendar.date(ofDay: finishedOn), difficulty: .easy, isSolved: solved, elapsedSeconds: 300)
            return GameRecord(result, dailyDay: day)
        }
        let records = [
            record(day: today - 2, finishedOn: today - 2),
            record(day: today - 1, finishedOn: today - 1),
            record(day: today - 5, finishedOn: today),            // a past day played today
            record(day: today, finishedOn: today, solved: false), // lost today
            GameRecord(GameResult(finishedAt: .now, difficulty: .hard, isSolved: true, elapsedSeconds: 60)), // not daily
        ]
        let daily = DailyRecords(records)
        #expect(daily.streak.current(today: today) == 2)
        #expect(daily.solvedDays == [today - 2, today - 1, today - 5])
        #expect(!daily.streak.solvedDays.contains(today - 5))
    }
}
