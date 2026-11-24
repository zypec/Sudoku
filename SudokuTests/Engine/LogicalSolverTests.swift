//
//  LogicalSolverTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("LogicalSolver")
struct LogicalSolverTests {
    private let solver = LogicalSolver()

    @Test func solvesAnEasyPuzzleWithSinglesOnly() throws {
        let result = solver.solve(try TestPuzzles.board(TestPuzzles.easy))
        #expect(result.isSolved)
        #expect(result.board.stringValue == TestPuzzles.easySolution)
        #expect(result.hardestTechnique?.level == 1)
        // 51 empty cells, each filled by exactly one placement.
        #expect(result.steps.count == 51)
    }

    @Test func everyStepAgreesWithTheSolution() throws {
        let solution = try TestPuzzles.values(TestPuzzles.easySolution)
        let result = solver.solve(try TestPuzzles.board(TestPuzzles.easy))
        for step in result.steps {
            for placement in step.placements {
                #expect(solution[placement.cell] == placement.digit, "\(step.technique) placed a wrong digit")
            }
            for elimination in step.eliminations {
                #expect(!elimination.digits.contains(solution[elimination.cell]), "\(step.technique) removed the solution")
            }
        }
    }

    @Test func triesTechniquesInOrder() throws {
        // One hole in an otherwise solved grid: a full house, a hidden single and a naked
        // single at the same time. The easiest technique must win.
        var values = try TestPuzzles.values(TestPuzzles.easySolution)
        values[0] = 0
        let step = try #require(solver.nextStep(on: Board(values: values)))
        #expect(step.technique == .fullHouse)
    }

    @Test func stopsWhenNoTechniqueApplies() throws {
        // Inkala's puzzle needs far more than singles.
        let board = try TestPuzzles.board(TestPuzzles.inkala)
        let result = solver.solve(board)
        #expect(!result.isSolved)
        #expect(result.board == board)
        #expect(result.steps.isEmpty)
        #expect(result.hardestTechnique == nil)
    }

    @Test func noStepOnSolvedOrContradictoryBoards() throws {
        #expect(solver.nextStep(on: try TestPuzzles.board(TestPuzzles.easySolution)) == nil)

        var values = try TestPuzzles.values(TestPuzzles.easy)
        values[2] = 5 // duplicate 5 in row 0
        #expect(solver.nextStep(on: Board(values: values)) == nil)
    }

    @Test func countsTechniqueUsage() throws {
        let result = solver.solve(try TestPuzzles.board(TestPuzzles.easy))
        let counts = result.techniqueCounts
        #expect(counts.values.reduce(0, +) == result.steps.count)
        #expect(Set(counts.keys).isSubset(of: [.fullHouse, .hiddenSingle, .nakedSingle]))
    }
}
