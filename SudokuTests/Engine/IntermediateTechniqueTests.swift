//
//  IntermediateTechniqueTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

/// Positions are built on an empty board by eliminating candidates, so each test isolates exactly
/// the pattern it checks.
@Suite("Intermediate techniques")
struct IntermediateTechniqueTests {
    /// Removes `digits` from every cell in `cells`.
    private func eliminating(_ digits: CandidateSet, from cells: some Sequence<CellIndex>, on board: Board = Board()) -> Board {
        var board = board
        for cell in cells {
            board.eliminate(digits, from: cell)
        }
        return board
    }

    /// Leaves exactly `candidates` in `cell`.
    private func restricting(_ cell: CellIndex, to candidates: CandidateSet, on board: Board) -> Board {
        var board = board
        board.eliminate(CandidateSet.all.subtracting(candidates), from: cell)
        return board
    }

    private func eliminatedCells(_ step: SolveStep) -> [CellIndex] {
        step.eliminations.map(\.cell).sorted()
    }

    // MARK: Combinations

    @Test func combinationsAreOrderedAndComplete() {
        #expect([1, 2, 3].combinations(ofSize: 2) == [[1, 2], [1, 3], [2, 3]])
        #expect([1, 2, 3].combinations(ofSize: 3) == [[1, 2, 3]])
        #expect([1, 2].combinations(ofSize: 3).isEmpty)
        #expect(Array(1...9).combinations(ofSize: 4).count == 126)
    }

    // MARK: Pointing

    @Test func pointingRemovesTheDigitFromTheRestOfTheLine() throws {
        // In box 0, digit 5 only fits in row 0 (cells 0, 1, 2).
        let board = eliminating([5], from: [9, 10, 11, 18, 19, 20])
        let step = try #require(Pointing().findStep(in: board))
        #expect(step.technique == .pointing)
        #expect(step.placements.isEmpty)
        #expect(eliminatedCells(step) == [3, 4, 5, 6, 7, 8])
        #expect(step.eliminations.allSatisfy { $0.digits == [5] })
        #expect(step.focusHouses == [House(kind: .box, index: 0), House(kind: .row, index: 0)])
        #expect(step.patternCells == [0, 1, 2])
    }

    @Test func pointingWorksAlongColumns() throws {
        // In box 4, digit 7 only fits in column 4 (cells 31, 40, 49).
        let board = eliminating([7], from: [30, 32, 39, 41, 48, 50])
        let step = try #require(Pointing().findStep(in: board))
        #expect(step.focusHouses == [House(kind: .box, index: 4), House(kind: .column, index: 4)])
        #expect(eliminatedCells(step) == [4, 13, 22, 58, 67, 76])
    }

    @Test func noPointingWhenNothingToEliminate() {
        // Digit 5 is confined to row 0 inside box 0, but already absent from the rest of row 0.
        let board = eliminating([5], from: [9, 10, 11, 18, 19, 20, 3, 4, 5, 6, 7, 8])
        #expect(Pointing().findStep(in: board) == nil)
    }

    // MARK: Claiming

    @Test func claimingRemovesTheDigitFromTheRestOfTheBox() throws {
        // In row 0, digit 5 only fits inside box 0.
        let board = eliminating([5], from: 3..<9)
        let step = try #require(Claiming().findStep(in: board))
        #expect(step.technique == .claiming)
        #expect(eliminatedCells(step) == [9, 10, 11, 18, 19, 20])
        #expect(step.focusHouses == [House(kind: .row, index: 0), House(kind: .box, index: 0)])
        // The same position offers no pointing: no box confines 5 to a single line.
        #expect(Pointing().findStep(in: board) == nil)
    }

    // MARK: Naked subsets

    @Test func nakedPair() throws {
        var board = restricting(0, to: [1, 2], on: Board())
        board = restricting(1, to: [1, 2], on: board)
        let step = try #require(NakedSubset(size: 2).findStep(in: board))
        #expect(step.technique == .nakedPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.patternDigits == [1, 2])
        // Box 0 is scanned first.
        #expect(step.focusHouses == [House(kind: .box, index: 0)])
        #expect(eliminatedCells(step) == [2, 9, 10, 11, 18, 19, 20])
        #expect(step.eliminations.allSatisfy { $0.digits == [1, 2] })
    }

    @Test func nakedTripleWithoutAnyCellHoldingAllThreeDigits() throws {
        var board = restricting(0, to: [1, 2], on: Board())
        board = restricting(1, to: [2, 3], on: board)
        board = restricting(2, to: [1, 3], on: board)
        #expect(NakedSubset(size: 2).findStep(in: board) == nil)

        let step = try #require(NakedSubset(size: 3).findStep(in: board))
        #expect(step.technique == .nakedTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(step.patternDigits == [1, 2, 3])
        #expect(eliminatedCells(step) == [9, 10, 11, 18, 19, 20])
    }

    @Test func nakedQuad() throws {
        var board = Board()
        for (cell, digits) in [(0, [1, 2]), (1, [2, 3]), (2, [3, 4]), (9, [1, 4])] as [(CellIndex, CandidateSet)] {
            board = restricting(cell, to: digits, on: board)
        }
        let step = try #require(NakedSubset(size: 4).findStep(in: board))
        #expect(step.technique == .nakedQuad)
        #expect(step.patternDigits == [1, 2, 3, 4])
        #expect(eliminatedCells(step) == [10, 11, 18, 19, 20])
    }

    // MARK: Hidden subsets

    @Test func hiddenPair() throws {
        // In box 0, digits 1 and 2 only fit in cells 0 and 1.
        let board = eliminating([1, 2], from: [2, 9, 10, 11, 18, 19, 20])
        let step = try #require(HiddenSubset(size: 2).findStep(in: board))
        #expect(step.technique == .hiddenPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.patternDigits == [1, 2])
        #expect(eliminatedCells(step) == [0, 1])
        #expect(step.eliminations.allSatisfy { $0.digits == [3, 4, 5, 6, 7, 8, 9] })
    }

    @Test func hiddenTriple() throws {
        // In box 0, digits 1, 2 and 3 only fit in cells 0, 1 and 2.
        let board = eliminating([1, 2, 3], from: [9, 10, 11, 18, 19, 20])
        #expect(HiddenSubset(size: 2).findStep(in: board) == nil)

        let step = try #require(HiddenSubset(size: 3).findStep(in: board))
        #expect(step.technique == .hiddenTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(eliminatedCells(step) == [0, 1, 2])
        #expect(step.eliminations.allSatisfy { $0.digits == [4, 5, 6, 7, 8, 9] })
    }

    @Test func hiddenQuad() throws {
        let board = eliminating([1, 2, 3, 4], from: [10, 11, 18, 19, 20])
        let step = try #require(HiddenSubset(size: 4).findStep(in: board))
        #expect(step.technique == .hiddenQuad)
        #expect(step.patternCells == [0, 1, 2, 9])
        #expect(step.eliminations.allSatisfy { $0.digits == [5, 6, 7, 8, 9] })
    }

    // MARK: Solver integration

    @Test func levelsMatchTheDifficultyTable() {
        let levelTwo: [TechniqueKind] = [.pointing, .claiming, .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple]
        #expect(levelTwo.allSatisfy { $0.level == 2 })
        #expect(TechniqueKind.nakedQuad.level == 3)
        #expect(TechniqueKind.hiddenQuad.level == 3)
    }

    @Test func solverListsEveryTechniqueInLevelOrder() {
        let kinds = LogicalSolver.standardTechniques.map(\.kind)
        #expect(Set(kinds) == Set(TechniqueKind.allCases))
        #expect(kinds.map(\.level) == kinds.map(\.level).sorted())
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func mediumPuzzlesNeedLevelTwoAndEveryStepIsCorrect(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let puzzle = PuzzleGenerator.generate(.medium, using: &generator)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))
        #expect(puzzle.givenCount >= PuzzleGenerator.minimumGivens(for: .medium))

        let result = LogicalSolver().solve(Board(values: puzzle.givens))
        #expect(result.isSolved)
        #expect(result.hardestTechnique?.level == 2)
        for step in result.steps {
            for placement in step.placements {
                #expect(puzzle.solution[placement.cell] == placement.digit)
            }
            for elimination in step.eliminations {
                #expect(!elimination.digits.contains(puzzle.solution[elimination.cell]), "\(step.technique) removed the solution")
            }
        }
    }
}
