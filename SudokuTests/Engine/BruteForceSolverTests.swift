//
//  BruteForceSolverTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("BruteForceSolver")
struct BruteForceSolverTests {
    @Test(arguments: [
        (TestPuzzles.easy, TestPuzzles.easySolution),
        (TestPuzzles.inkala, TestPuzzles.inkalaSolution),
    ])
    func findsTheUniqueSolution(puzzle: String, solution: String) throws {
        let values = try TestPuzzles.values(puzzle)
        #expect(BruteForceSolver.countSolutions(of: values) == 1)
        #expect(BruteForceSolver.hasUniqueSolution(values))
        #expect(BruteForceSolver.solution(of: values) == (try TestPuzzles.values(solution)))
    }

    @Test func stopsCountingAtTheLimit() throws {
        let values = try TestPuzzles.values(TestPuzzles.multipleSolutions)
        #expect(BruteForceSolver.countSolutions(of: values, limit: 2) == 2)
        #expect(!BruteForceSolver.hasUniqueSolution(values))

        let empty = Board().values
        #expect(BruteForceSolver.countSolutions(of: empty, limit: 5) == 5)
    }

    @Test func conflictingGivensHaveNoSolution() throws {
        var values = try TestPuzzles.values(TestPuzzles.easy)
        values[2] = 5 // second 5 in row 0
        #expect(BruteForceSolver.countSolutions(of: values) == 0)
        #expect(BruteForceSolver.solution(of: values) == nil)
    }

    @Test func unsolvableButConflictFreeGridHasNoSolution() {
        // Row 0 holds 1-8 in columns 0-7, and column 8 already contains a 9 lower down,
        // so the top-right cell has no legal digit.
        var values = Array(1...8) + [0]
        values += Array(repeating: 0, count: 72)
        values[Geometry.cell(row: 5, column: 8)] = 9
        #expect(BruteForceSolver.countSolutions(of: values) == 0)
    }

    @Test func aSolvedGridIsItsOwnSolution() throws {
        let values = try TestPuzzles.values(TestPuzzles.easySolution)
        #expect(BruteForceSolver.countSolutions(of: values) == 1)
        #expect(BruteForceSolver.solution(of: values) == values)
    }
}
