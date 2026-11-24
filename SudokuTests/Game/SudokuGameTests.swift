//
//  SudokuGameTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@Suite("SudokuGame")
struct SudokuGameTests {
    /// The classic easy puzzle. Cell 2 (row 0, column 2) is empty with candidates {1, 2, 4} and solution 4.
    /// Cell 3 is empty in the same row; cell 78 (row 8, column 6) is empty and unrelated to cell 2.
    private func makeGame(mistakeLimit: Int? = 3) throws -> SudokuGame {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        return SudokuGame(puzzle: puzzle, mistakeLimit: mistakeLimit)
    }

    @Test func startsWithTheGivens() throws {
        let game = try makeGame()
        #expect(game.values == game.puzzle.givens)
        #expect(game.isGiven(0))
        #expect(!game.isGiven(2))
        #expect(game.mistakeCount == 0)
        #expect(!game.isFinished)
    }

    @Test func correctEntryIsPlaced() throws {
        var game = try makeGame()
        let result = game.enter(4, at: 2)
        #expect(result == .placed)
        #expect(game.values[2] == 4)
        #expect(!game.isIncorrect(2))
        #expect(game.mistakeCount == 0)
    }

    @Test func wrongEntryCountsAsMistake() throws {
        var game = try makeGame()
        let result = game.enter(1, at: 2)
        #expect(result == .mistake)
        #expect(game.values[2] == 1)
        #expect(game.isIncorrect(2))
        #expect(game.mistakeCount == 1)
    }

    @Test func givensAndRepeatedEntriesAreIgnored() throws {
        var game = try makeGame()
        let onGiven = game.enter(1, at: 0)
        let erasedGiven = game.erase(at: 0)
        game.enter(1, at: 2)
        let repeated = game.enter(1, at: 2)
        #expect(onGiven == .ignored)
        #expect(!erasedGiven)
        #expect(repeated == .ignored)
        #expect(game.mistakeCount == 1)
    }

    @Test func reachingTheMistakeLimitLosesTheGame() throws {
        var game = try makeGame(mistakeLimit: 2)
        game.enter(1, at: 2)
        game.enter(2, at: 2)
        #expect(game.isLost)
        #expect(game.isFinished)
        // No more input once the game is over.
        let afterLoss = game.enter(4, at: 2)
        #expect(afterLoss == .ignored)
        #expect(!game.canUndo)
    }

    @Test func unlimitedMistakesNeverLose() throws {
        var game = try makeGame(mistakeLimit: nil)
        for digit in [1, 2, 1, 2, 1, 2] {
            game.enter(digit, at: 2)
        }
        #expect(game.mistakeCount == 6)
        #expect(!game.isLost)
    }

    @Test func fillingEveryCellCorrectlySolvesTheGame() throws {
        var game = try makeGame()
        for cell in Geometry.cells where !game.isGiven(cell) {
            game.enter(game.puzzle.solution[cell], at: cell)
        }
        #expect(game.isSolved)
        #expect(game.isFinished)
        #expect(game.mistakeCount == 0)
    }

    @Test func notesOnlyGoInEmptyCells() throws {
        var game = try makeGame()
        game.toggleNote(1, at: 2)
        game.toggleNote(2, at: 2)
        #expect(game.notes[2] == [1, 2])
        game.toggleNote(1, at: 2)
        #expect(game.notes[2] == [2])

        let onGiven = game.toggleNote(1, at: 0)
        #expect(!onGiven)
        #expect(game.notes[0].isEmpty)
    }

    @Test func correctEntryClearsPeerNotesButWrongEntryDoesNot() throws {
        var game = try makeGame()
        game.toggleNote(4, at: 3)
        game.toggleNote(4, at: 78)
        game.enter(4, at: 2)
        #expect(!game.notes[3].contains(4))
        #expect(game.notes[78].contains(4))

        var other = try makeGame()
        other.toggleNote(1, at: 3)
        other.enter(1, at: 2) // wrong digit
        #expect(other.notes[3].contains(1))
    }

    @Test func eraseClearsEntryAndNotes() throws {
        var game = try makeGame()
        game.enter(1, at: 2)
        let erasedEntry = game.erase(at: 2)
        let erasedEmpty = game.erase(at: 2)
        #expect(erasedEntry)
        #expect(!erasedEmpty)
        #expect(game.values[2] == 0)

        game.toggleNote(5, at: 2)
        let erasedNotes = game.erase(at: 2)
        #expect(erasedNotes)
        #expect(game.notes[2].isEmpty)
    }

    @Test func fillNotesUsesPlacedDigits() throws {
        var game = try makeGame()
        let first = game.fillNotes()
        let second = game.fillNotes()
        #expect(first)
        #expect(!second) // nothing changes the second time
        #expect(game.notes[2] == [1, 2, 4])
        #expect(game.notes[0].isEmpty)
    }

    @Test func undoAndRedoRestoreEntriesButNotMistakes() throws {
        var game = try makeGame()
        game.enter(1, at: 2)
        game.toggleNote(3, at: 3)

        game.undo()
        #expect(game.notes[3].isEmpty)
        game.undo()
        #expect(game.values[2] == 0)
        #expect(game.mistakeCount == 1)
        #expect(!game.canUndo)

        game.redo()
        #expect(game.values[2] == 1)
        game.redo()
        #expect(game.notes[3] == [3])
        #expect(!game.canRedo)
    }

    @Test func newActionClearsRedo() throws {
        var game = try makeGame()
        game.enter(4, at: 2)
        game.undo()
        #expect(game.canRedo)
        game.toggleNote(1, at: 3)
        #expect(!game.canRedo)
    }

    @Test func remainingCountIgnoresWrongEntries() throws {
        var game = try makeGame()
        let fourBefore = game.remainingCount(of: 4)
        let oneBefore = game.remainingCount(of: 1)
        game.enter(4, at: 2) // correct
        game.enter(1, at: 3) // wrong (solution is 6)
        #expect(game.remainingCount(of: 4) == fourBefore - 1)
        #expect(game.remainingCount(of: 1) == oneBefore)
    }

    @Test func roundTripsThroughCodable() throws {
        var game = try makeGame()
        game.enter(4, at: 2)
        game.toggleNote(1, at: 3)
        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SudokuGame.self, from: data)
        #expect(decoded.values == game.values)
        #expect(decoded.notes == game.notes)
        #expect(decoded.canUndo)
    }
}
