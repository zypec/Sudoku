//
//  PuzzleBankTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@Suite("Puzzle bank")
struct PuzzleBankTests {
    private func easyPuzzle() throws -> Puzzle {
        Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy,
            estimatedSeconds: 400,
            requiredTechniques: [.hiddenSingle]
        )
    }

    // MARK: Transform

    @Test func identityChangesNothing() throws {
        let puzzle = try easyPuzzle()
        #expect(PuzzleTransform.identity.apply(to: puzzle) == puzzle)
    }

    @Test(arguments: [1, 2, 3, 4, 5, 6, 7, 8] as [UInt64])
    func transformsKeepAValidUniquePuzzle(seed: UInt64) throws {
        let puzzle = try easyPuzzle()
        var generator = SeededRandomNumberGenerator(seed: seed)
        let transformed = PuzzleTransform.random(using: &generator).apply(to: puzzle)

        #expect(Board(values: transformed.solution).isSolved)
        #expect(transformed.givenCount == puzzle.givenCount)
        // Every given still agrees with the solution.
        #expect(Geometry.cells.allSatisfy { transformed.givens[$0] == 0 || transformed.givens[$0] == transformed.solution[$0] })
        #expect(BruteForceSolver.solution(of: transformed.givens) == transformed.solution)
        #expect(transformed.estimatedSeconds == puzzle.estimatedSeconds)
        #expect(transformed.requiredTechniques == puzzle.requiredTechniques)
    }

    @Test func sameSeedGivesTheSameTransform() {
        var first = SeededRandomNumberGenerator(seed: 42)
        var second = SeededRandomNumberGenerator(seed: 42)
        #expect(PuzzleTransform.random(using: &first) == PuzzleTransform.random(using: &second))
    }

    /// The transforms are symmetries of the rules, so the logic needed stays at the same level.
    @Test(arguments: [Difficulty.medium, .hard, .expert])
    func transformsKeepTheDifficulty(difficulty: Difficulty) throws {
        let bank = PuzzleBank.bundled
        for index in 0..<3 {
            let stored = try #require(bank.puzzle(difficulty, at: index))
            for seed in UInt64(1)...3 {
                var generator = SeededRandomNumberGenerator(seed: seed)
                let transformed = PuzzleTransform.random(using: &generator).apply(to: stored)
                let result = LogicalSolver().solve(Board(values: transformed.givens))
                #expect(result.isSolved)
                #expect(result.hardestTechnique?.level == difficulty.level)
            }
        }
    }

    // MARK: Bundled bank

    @Test func bundledBankCoversEveryDifficulty() {
        for difficulty in Difficulty.allCases {
            #expect(PuzzleBank.bundled.count(of: difficulty) >= 100, "\(difficulty)")
        }
    }

    /// A sample of stored puzzles: unique solution, matching givens and grading.
    @Test(arguments: Difficulty.allCases)
    func storedPuzzlesAreValid(difficulty: Difficulty) throws {
        let bank = PuzzleBank.bundled
        let count = bank.count(of: difficulty)
        for index in stride(from: 0, to: count, by: max(1, count / 8)) {
            let puzzle = try #require(bank.puzzle(difficulty, at: index))
            #expect(BruteForceSolver.solution(of: puzzle.givens) == puzzle.solution)
            #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))
            #expect((puzzle.estimatedSeconds ?? 0) > 0)
            let levels = (puzzle.requiredTechniques ?? []).map(\.level)
            #expect(levels.max() == difficulty.level)
        }
    }

    @Test func entriesRoundTrip() throws {
        let puzzle = try easyPuzzle()
        let file = PuzzleBank.File(version: PuzzleBank.fileVersion, puzzles: ["1": [PuzzleBank.entry(for: puzzle)]])
        let bank = try PuzzleBank(data: JSONEncoder().encode(file))
        #expect(bank.count(of: .easy) == 1)
        #expect(bank.count(of: .hard) == 0)
        #expect(bank.puzzle(.easy, at: 0) == puzzle)
        #expect(bank.puzzle(.easy, at: 1) == nil)
    }

    // MARK: Source

    @MainActor
    @Test func sourceCyclesThroughEveryPuzzleBeforeRepeating() throws {
        let puzzle = try easyPuzzle()
        let entries = Array(repeating: PuzzleBank.entry(for: puzzle), count: 7)
        let bank = PuzzleBank(file: PuzzleBank.File(version: 1, puzzles: ["1": entries]))
        let defaults = try #require(UserDefaults(suiteName: "PuzzleBankTests.\(UUID().uuidString)"))
        let source = PuzzleSource(bank: bank, defaults: defaults)

        let firstRound = (0..<7).compactMap { _ in source.nextIndex(for: .easy) }
        #expect(Set(firstRound) == Set(0..<7))
        let secondRound = (0..<7).compactMap { _ in source.nextIndex(for: .easy) }
        #expect(Set(secondRound) == Set(0..<7))

        // The position survives a new source on the same defaults (an app restart).
        let restarted = PuzzleSource(bank: bank, defaults: defaults)
        _ = restarted.nextIndex(for: .easy)
        #expect(source.nextIndex(for: .hard) == nil)
    }

    @MainActor
    @Test func sourceTransformsStoredPuzzlesAndFallsBackToTheGenerator() async throws {
        let puzzle = try easyPuzzle()
        let bank = PuzzleBank(file: PuzzleBank.File(version: 1, puzzles: ["1": [PuzzleBank.entry(for: puzzle)]]))
        let defaults = try #require(UserDefaults(suiteName: "PuzzleBankTests.\(UUID().uuidString)"))
        let source = PuzzleSource(bank: bank, defaults: defaults)

        let fromBank = await source.puzzle(.easy)
        #expect(fromBank.difficulty == .easy)
        #expect(fromBank.givenCount == puzzle.givenCount)
        #expect(BruteForceSolver.solution(of: fromBank.givens) == fromBank.solution)

        // Nothing stored for Medium: generated on the spot.
        let generated = await source.puzzle(.medium)
        #expect(generated.difficulty == .medium)
        #expect(BruteForceSolver.hasUniqueSolution(generated.givens))
    }
}
