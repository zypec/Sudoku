//
//  RaceTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@MainActor
@Suite("Races")
struct RaceTests {
    private let store: RaceStore

    init() {
        store = RaceStore(folder: URL.temporaryDirectory.appending(path: "Races \(UUID().uuidString)"))
    }

    /// A race code on a bank puzzle, ending at `deadline`.
    private func raceCode(deadline: Date, salt: UInt64 = 7) throws -> (code: String, puzzle: Puzzle) {
        let stored = try #require(PuzzleBank.bundled.puzzle(.easy, at: 3))
        var puzzle = PuzzleTransform.seeded(42).apply(to: stored)
        puzzle.origin = Puzzle.Origin(index: 3, seed: 42)
        return (try #require(RaceCode.raceCode(puzzleCode: PuzzleCode.code(for: puzzle), deadline: deadline, salt: salt)), puzzle)
    }

    @Test func aRaceCodeCarriesThePuzzleAndTheDeadline() throws {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let (code, puzzle) = try raceCode(deadline: deadline)
        #expect(code.count == 19)
        let parsed = try #require(RaceCode.parseRace(code.lowercased()))
        #expect(PuzzleCode.puzzle(from: parsed.puzzleCode) == puzzle)
        // Rounded up to the hour.
        #expect(parsed.deadline >= deadline && parsed.deadline.timeIntervalSince(deadline) < 3600)
        #expect(RaceCode.parseRace("H7K-2M4-Q9X") == nil)
    }

    @Test func aResultCodeBelongsToItsRace() throws {
        let finished = Date(timeIntervalSince1970: 1_790_000_000)
        let code = RaceCode.resultCode(raceID: "RACE1", name: "Ada", finishedAt: finished, seconds: 754)
        let result = try #require(RaceCode.parseResult(code, raceID: "RACE1"))
        #expect(result.name == "Ada")
        #expect(result.seconds == 754)
        #expect(abs(result.finishedAt.timeIntervalSince(finished)) < 60)
        #expect(RaceCode.parseResult(code, raceID: "RACE2") == nil)
        // Another name on the same code doesn't check out.
        let head = String(code.prefix { $0 != " " })
        #expect(RaceCode.parseResult(head + " Bob", raceID: "RACE1") == nil)
    }

    @Test func standingsPutTheFirstFinisherInTimeFirst() throws {
        let now = Date.now
        let (code, puzzle) = try raceCode(deadline: now.addingTimeInterval(86400))
        let race = try store.join(code, now: now)
        #expect(race.puzzle == puzzle)
        #expect(try store.join(code) == race)  // joining twice is the same race

        // This player solves it.
        var game = SudokuGame(puzzle: race.puzzle, mistakeLimit: nil)
        for cell in Geometry.cells where game.values[cell] == 0 {
            game.enter(race.puzzle.solution[cell], at: cell)
        }
        store.finish(race.id, game: game, at: now.addingTimeInterval(1200))
        #expect(store.race(race.id)?.myResult != nil)

        // A friend before, and one after the deadline.
        let early = RaceCode.resultCode(raceID: race.id, name: "Ada", finishedAt: now.addingTimeInterval(600), seconds: 500)
        let late = RaceCode.resultCode(raceID: race.id, name: "Bob", finishedAt: now.addingTimeInterval(200_000), seconds: 300)
        #expect(store.addResult(early, to: race.id))
        #expect(store.addResult(early, to: race.id))  // added once
        #expect(store.addResult(late, to: race.id))
        #expect(!store.addResult("not a code", to: race.id))

        let updated = try #require(store.race(race.id))
        let standings = updated.standings(myName: "")
        #expect(standings.map(\.result.name) == ["Ada", "", "Bob"])
        #expect(standings.map(\.inTime) == [true, true, false])
        #expect(updated.winner?.name == "Ada")
    }

    @Test func aLostGameGivesNoResult() throws {
        let (code, _) = try raceCode(deadline: .now.addingTimeInterval(3600))
        let race = try store.join(code)
        var game = SudokuGame(puzzle: race.puzzle, mistakeLimit: 1)
        let cell = try #require(Geometry.cells.first { game.values[$0] == 0 })
        game.enter(race.puzzle.solution[cell] % 9 + 1, at: cell)
        #expect(game.isLost)
        store.finish(race.id, game: game)
        #expect(store.race(race.id)?.myResult == nil)
    }
}
