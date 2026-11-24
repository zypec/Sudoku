//
//  SingleTechniqueTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("Single techniques")
struct SingleTechniqueTests {
    /// The solved easy grid with `cells` emptied again.
    private func solvedBoard(removing cells: [CellIndex]) throws -> Board {
        var values = try TestPuzzles.values(TestPuzzles.easySolution)
        for cell in cells {
            values[cell] = 0
        }
        return Board(values: values)
    }

    // MARK: Full House

    @Test func fullHouseFillsTheLastEmptyCellOfAHouse() throws {
        // Emptying row 0, column 0 (a 5) leaves every house around it with one hole.
        let board = try solvedBoard(removing: [0])
        let step = try #require(FullHouse().findStep(in: board))
        #expect(step.technique == .fullHouse)
        #expect(step.placements == [Placement(cell: 0, digit: 5)])
        #expect(step.focusHouses == [House(kind: .box, index: 0)])
        #expect(step.eliminations.isEmpty)
    }

    @Test func fullHouseNeedsExactlyOneEmptyCell() throws {
        // Empty two cells of every house the first one belongs to.
        let board = try solvedBoard(removing: [0, 1, 9, 10])
        #expect(FullHouse().findStep(in: board) == nil)
    }

    // MARK: Hidden Single

    @Test func hiddenSingleFindsTheOnlySpotForADigitInAHouse() throws {
        var board = Board()
        // Digit 5 is ruled out of row 0 everywhere except the first cell.
        for cell in 1..<9 {
            board.eliminate([5], from: cell)
        }
        let step = try #require(HiddenSingle().findStep(in: board))
        #expect(step.technique == .hiddenSingle)
        #expect(step.placements == [Placement(cell: 0, digit: 5)])
        #expect(step.focusHouses == [House(kind: .row, index: 0)])
        #expect(step.patternDigits == [5])
    }

    @Test func hiddenSinglePrefersBoxes() throws {
        var board = Board()
        // Digit 4 only fits the center cell of box 4, and digit 5 only fits cell 0 of row 0.
        for cell in House(kind: .box, index: 4).cells where cell != 40 {
            board.eliminate([4], from: cell)
        }
        for cell in 1..<9 {
            board.eliminate([5], from: cell)
        }
        let step = try #require(HiddenSingle().findStep(in: board))
        #expect(step.placements == [Placement(cell: 40, digit: 4)])
        #expect(step.focusHouses == [House(kind: .box, index: 4)])
    }

    @Test func noHiddenSingleOnAnEmptyBoard() {
        #expect(HiddenSingle().findStep(in: Board()) == nil)
    }

    // MARK: Naked Single

    @Test func nakedSingleFindsACellWithOneCandidate() throws {
        var board = Board()
        board.eliminate([1, 2, 3, 4, 5, 6, 7, 8], from: 0)
        let step = try #require(NakedSingle().findStep(in: board))
        #expect(step.technique == .nakedSingle)
        #expect(step.placements == [Placement(cell: 0, digit: 9)])
        #expect(step.focusHouses == Geometry.houses(containing: 0))
        // The same position has no hidden single: 9 still fits elsewhere in every house.
        #expect(HiddenSingle().findStep(in: board) == nil)
    }

    @Test func nakedSingleIgnoresFilledCells() {
        var board = Board()
        board.place(3, at: 0)
        #expect(NakedSingle().findStep(in: board) == nil)
    }
}
