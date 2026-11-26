//
//  DailyPuzzle.swift
//  Sudoku
//

/// The puzzle of the day, the same for everyone without a server: a day is a number (days since
/// January 1, 2026, counted in calendar days, so a time zone never changes which puzzle a date has),
/// and the number picks a bank puzzle and the transform it is shown in.
///
/// The difficulty follows the week: Monday and Tuesday easy, Wednesday and Thursday medium, Friday and
/// Saturday hard, Sunday expert.
enum DailyPuzzle {
    /// Day 0, January 1, 2026, was a Thursday.
    private static let firstWeekday = 3  // 0 is Monday

    /// 0 for Monday through 6 for Sunday.
    static func weekday(ofDay day: Int) -> Int {
        ((day + firstWeekday) % 7 + 7) % 7
    }

    static func difficulty(forDay day: Int) -> Difficulty {
        switch weekday(ofDay: day) {
        case 0, 1: .easy
        case 2, 3: .medium
        case 4, 5: .hard
        default: .expert
        }
    }

    /// The day's puzzle, with its origin set so it has a short code. `nil` only if the bank has no
    /// puzzle of the day's difficulty.
    static func puzzle(forDay day: Int, bank: PuzzleBank = .bundled) -> Puzzle? {
        let difficulty = difficulty(forDay: day)
        let count = bank.count(of: difficulty)
        guard count > 0 else { return nil }
        // A prime step walks through every puzzle of the bank before one comes back (the bank's sizes
        // aren't multiples of it), so days far apart rarely share a puzzle.
        let index = ((day * 7_919 + 104_729) % count + count) % count
        guard let stored = bank.puzzle(difficulty, at: index) else { return nil }
        let seed = UInt32(truncatingIfNeeded: (UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15) >> 34) % PuzzleCode.seedLimit
        var puzzle = PuzzleTransform.seeded(seed).apply(to: stored)
        puzzle.origin = Puzzle.Origin(index: index, seed: seed)
        return puzzle
    }
}

/// The days the daily puzzle was solved on its own day, and the streaks they make.
struct DailyStreak: Equatable, Sendable {
    /// Days whose puzzle was solved on that same day.
    let solvedDays: Set<Int>

    init(solvedDays: Set<Int>) {
        self.solvedDays = solvedDays
    }

    /// From finished daily games: the day each puzzle belongs to and the day it was solved.
    init(solved: [(puzzleDay: Int, solvedOn: Int)]) {
        solvedDays = Set(solved.filter { $0.puzzleDay == $0.solvedOn }.map(\.puzzleDay))
    }

    /// Consecutive days solved, ending today, or yesterday while today's puzzle is still open: a
    /// streak only breaks once a whole day has gone by without its puzzle.
    func current(today: Int) -> Int {
        var day = solvedDays.contains(today) ? today : today - 1
        var count = 0
        while solvedDays.contains(day) {
            count += 1
            day -= 1
        }
        return count
    }

    var best: Int {
        var best = 0
        for day in solvedDays where !solvedDays.contains(day - 1) {
            var length = 1
            while solvedDays.contains(day + length) {
                length += 1
            }
            best = max(best, length)
        }
        return best
    }
}
