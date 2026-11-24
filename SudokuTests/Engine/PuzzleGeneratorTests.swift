//
//  PuzzleGeneratorTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("PuzzleGenerator")
struct PuzzleGeneratorTests {
    @Test func seededGeneratorIsDeterministic() {
        var a = SeededRandomNumberGenerator(seed: 42)
        var b = SeededRandomNumberGenerator(seed: 42)
        var c = SeededRandomNumberGenerator(seed: 43)
        let first = (0..<5).map { _ in a.next() }
        #expect(first == (0..<5).map { _ in b.next() })
        #expect(first != (0..<5).map { _ in c.next() })
    }

    @Test func stableShuffleIsAPermutation() {
        var generator = SeededRandomNumberGenerator(seed: 7)
        var digits = Array(1...9)
        digits.stableShuffle(using: &generator)
        #expect(digits.sorted() == Array(1...9))
        #expect(digits != Array(1...9))
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func solvedGridIsValid(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let grid = PuzzleGenerator.makeSolvedGrid(using: &generator)
        #expect(Board(values: grid).isSolved)
    }

    @Test(arguments: [1, 2, 3, 4, 5] as [UInt64])
    func easyPuzzlesAreUniqueSymmetricAndSinglesOnly(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let puzzle = PuzzleGenerator.generate(.easy, using: &generator)

        #expect(puzzle.difficulty == .easy)
        #expect(Board(values: puzzle.solution).isSolved)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))
        #expect(BruteForceSolver.solution(of: puzzle.givens) == puzzle.solution)
        #expect(puzzle.givenCount >= PuzzleGenerator.minimumGivens(for: .easy))

        // Every given matches the solution.
        for cell in Geometry.cells where puzzle.givens[cell] != 0 {
            #expect(puzzle.givens[cell] == puzzle.solution[cell])
        }
        // Clues are symmetric under 180° rotation.
        for cell in Geometry.cells {
            #expect((puzzle.givens[cell] == 0) == (puzzle.givens[80 - cell] == 0))
        }
        // Solvable with level-1 techniques only.
        let result = LogicalSolver().solve(Board(values: puzzle.givens))
        #expect(result.isSolved)
        #expect(result.hardestTechnique?.level == 1)
    }

    @Test func sameSeedGivesSamePuzzle() {
        var a = SeededRandomNumberGenerator(seed: 2026)
        var b = SeededRandomNumberGenerator(seed: 2026)
        #expect(PuzzleGenerator.generate(.easy, using: &a) == PuzzleGenerator.generate(.easy, using: &b))
    }

    @Test func asyncGenerationProducesAValidPuzzle() async {
        let puzzle = await PuzzleGenerator.generate(.easy)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))
    }
}
