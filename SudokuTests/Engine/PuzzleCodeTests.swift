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

    @Test func aBankPuzzleGetsAShortCode() throws {
        let bank = PuzzleBank.bundled
        let stored = try #require(bank.puzzle(.hard, at: 37))
        var puzzle = PuzzleTransform.seeded(123_456_789).apply(to: stored)
        puzzle.origin = Puzzle.Origin(index: 37, seed: 123_456_789)
        let code = PuzzleCode.code(for: puzzle)
        #expect(code.count == 11)
        #expect(code.filter { $0 == "-" }.count == 2)
        #expect(PuzzleCode.puzzle(from: code) == puzzle)
        // Typed by hand: no dashes, small letters, an O for a 0.
        let typed = code.replacingOccurrences(of: "-", with: "").lowercased().replacingOccurrences(of: "0", with: "o")
        #expect(PuzzleCode.puzzle(from: typed) == puzzle)
    }

    @Test func shortCodesOutsideTheBankAreRefused() {
        #expect(PuzzleCode.puzzle(from: "ZZZ-ZZZ-ZZZ") == nil)  // another bank generation
        #expect(PuzzleCode.puzzle(from: "2ZZ-000-000") == nil)  // no puzzle at that index
        #expect(PuzzleCode.puzzle(from: "200-000") == nil)
        #expect(PuzzleCode.puzzle(from: "2U0-000-000") == nil)  // U isn't in the alphabet
    }

    @Test func aPuzzleMadeOnTheDeviceIsWrittenOut() throws {
        let puzzle = Puzzle(givens: try TestPuzzles.values(TestPuzzles.easy), solution: try TestPuzzles.values(TestPuzzles.easySolution), difficulty: .easy)
        #expect(PuzzleCode.code(for: puzzle).hasPrefix(PuzzleCode.prefix))
    }
}
