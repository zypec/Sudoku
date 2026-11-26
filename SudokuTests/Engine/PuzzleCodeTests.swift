//
//  PuzzleCodeTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("Puzzle codes")
struct PuzzleCodeTests {
    @Test func aCodeGivesBackTheSameGivens() throws {
        let givens = try TestPuzzles.values(TestPuzzles.easy)
        let code = PuzzleCode.code(for: givens)
        #expect(code.hasPrefix(PuzzleCode.prefix))
        #expect(code.count < 60)
        #expect(PuzzleCode.givens(from: code) == givens)
        // Pasted codes may carry spaces and other letter cases.
        #expect(PuzzleCode.givens(from: "  " + code.uppercased() + "\n") == givens)
    }

    @Test func aCodeMakesAGradedPuzzle() throws {
        let code = PuzzleCode.code(for: try TestPuzzles.values(TestPuzzles.easy))
        let puzzle = try #require(PuzzleCode.puzzle(from: code))
        #expect(puzzle.solution == (try TestPuzzles.values(TestPuzzles.easySolution)))
        #expect(puzzle.difficulty == .easy)
        #expect(puzzle.estimatedSeconds != nil)
    }

    @Test func longRunsOfEmptyCellsSplit() {
        let givens = [5] + Array(repeating: 0, count: 79) + [9]
        let code = PuzzleCode.code(for: givens)
        #expect(code == "S1-5zzza9")
        #expect(PuzzleCode.givens(from: code) == givens)
    }

    @Test func whatIsNotAPuzzleIsRefused() throws {
        #expect(PuzzleCode.givens(from: "hello") == nil)
        #expect(PuzzleCode.givens(from: "S1-123") == nil)
        #expect(PuzzleCode.givens(from: "S1-5zzza9?") == nil)
        // A real code whose puzzle has more than one solution.
        #expect(PuzzleCode.puzzle(from: "S1-5zzza9") == nil)
    }
}
