//
//  ExpertTechniqueTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

/// Level 4 patterns, built on an empty board by eliminating candidates so each test isolates
/// exactly the pattern it checks.
@Suite("Expert techniques")
struct ExpertTechniqueTests {
    private func cell(_ row: Int, _ column: Int) -> CellIndex {
        Geometry.cell(row: row, column: column)
    }

    private func row(_ index: Int) -> House { House(kind: .row, index: index) }
    private func column(_ index: Int) -> House { House(kind: .column, index: index) }
    private func box(_ index: Int) -> House { House(kind: .box, index: index) }

    /// Leaves `digit` only in `keep` within `house`.
    private func confining(_ digit: Digit, in house: House, to keep: [CellIndex], on board: Board = Board()) -> Board {
        var board = board
        for cell in house.cells where !keep.contains(cell) {
            board.eliminate([digit], from: cell)
        }
        return board
    }

    /// Leaves exactly `candidates` in each cell.
    private func restricting(_ cells: [(CellIndex, CandidateSet)], on board: Board = Board()) -> Board {
        var board = board
        for (cell, candidates) in cells {
            board.eliminate(CandidateSet.all.subtracting(candidates), from: cell)
        }
        return board
    }

    /// Every elimination removes exactly `digits`; returns the affected cells, sorted.
    private func cells(of step: SolveStep, removing digits: CandidateSet) -> [CellIndex] {
        #expect(step.placements.isEmpty)
        #expect(step.eliminations.allSatisfy { $0.digits == digits })
        return step.eliminations.map(\.cell).sorted()
    }

    // MARK: Fish

    @Test func swordfish() throws {
        // Rows 0, 4 and 8 hold 5 only in columns 1, 4 and 7 (2-2-2).
        var board = confining(5, in: row(0), to: [cell(0, 1), cell(0, 4)])
        board = confining(5, in: row(4), to: [cell(4, 4), cell(4, 7)], on: board)
        board = confining(5, in: row(8), to: [cell(8, 1), cell(8, 7)], on: board)
        #expect(BasicFish.xWing.findStep(in: board) == nil)

        let step = try #require(BasicFish.swordfish.findStep(in: board))
        #expect(step.technique == .swordfish)
        #expect(step.focusHouses == [row(0), row(4), row(8), column(1), column(4), column(7)])
        let expected = [1, 2, 3, 5, 6, 7].flatMap { r in [1, 4, 7].map { cell(r, $0) } }.sorted()
        #expect(cells(of: step, removing: [5]) == expected)
    }

    @Test func jellyfish() throws {
        // Rows 0, 2, 4 and 6 hold 3 only in columns 0, 3, 5 and 8.
        var board = confining(3, in: row(0), to: [cell(0, 0), cell(0, 3)])
        board = confining(3, in: row(2), to: [cell(2, 3), cell(2, 5)], on: board)
        board = confining(3, in: row(4), to: [cell(4, 5), cell(4, 8)], on: board)
        board = confining(3, in: row(6), to: [cell(6, 8), cell(6, 0)], on: board)
        #expect(BasicFish.swordfish.findStep(in: board) == nil)

        let step = try #require(BasicFish.jellyfish.findStep(in: board))
        #expect(step.technique == .jellyfish)
        let expected = [1, 3, 5, 7, 8].flatMap { r in [0, 3, 5, 8].map { cell(r, $0) } }.sorted()
        #expect(cells(of: step, removing: [3]) == expected)
    }

    @Test func finnedXWing() throws {
        // Rows 1 and 5 hold 7 in columns 2 and 6, plus a fin at r2c8 in box 2.
        var board = confining(7, in: row(1), to: [cell(1, 2), cell(1, 6), cell(1, 7)])
        board = confining(7, in: row(5), to: [cell(5, 2), cell(5, 6)], on: board)
        #expect(BasicFish.xWing.findStep(in: board) == nil)

        let step = try #require(FinnedFish.xWing.findStep(in: board))
        #expect(step.technique == .finnedXWing)
        #expect(step.focusHouses == [row(1), row(5), column(2), column(6), box(2)])
        // Only the cover cells inside the fin's box lose the digit.
        #expect(cells(of: step, removing: [7]) == [cell(0, 6), cell(2, 6)])
    }

    @Test func finnedSwordfish() throws {
        // The swordfish from above plus a fin at r0c2 in box 0.
        var board = confining(5, in: row(0), to: [cell(0, 1), cell(0, 2), cell(0, 4)])
        board = confining(5, in: row(4), to: [cell(4, 4), cell(4, 7)], on: board)
        board = confining(5, in: row(8), to: [cell(8, 1), cell(8, 7)], on: board)
        #expect(BasicFish.swordfish.findStep(in: board) == nil)

        let step = try #require(FinnedFish.swordfish.findStep(in: board))
        #expect(step.technique == .finnedSwordfish)
        #expect(step.focusHouses.last == box(0))
        #expect(cells(of: step, removing: [5]) == [cell(1, 1), cell(2, 1)])
    }

    // MARK: Empty Rectangle

    @Test func emptyRectangle() throws {
        // In box 0, 4 only fits on row 1 and column 1. Column 5 holds 4 only in r1c5 and r7c5.
        var board = Board()
        for corner in [cell(0, 0), cell(0, 2), cell(2, 0), cell(2, 2)] {
            board.eliminate([4], from: corner)
        }
        board = confining(4, in: column(5), to: [cell(1, 5), cell(7, 5)], on: board)

        let step = try #require(EmptyRectangle().findStep(in: board))
        #expect(step.technique == .emptyRectangle)
        #expect(step.focusHouses == [box(0), column(5), row(1), column(1)])
        #expect(Array(step.patternCells.prefix(2)) == [cell(1, 5), cell(7, 5)])
        #expect(cells(of: step, removing: [4]) == [cell(7, 1)])
    }

    @Test func noEmptyRectangleWhenTheBoxUsesOneLine() {
        // Every 4 of box 0 is on row 1: that's a pointing pattern, not an empty rectangle.
        var board = confining(4, in: box(0), to: [cell(1, 0), cell(1, 1), cell(1, 2)])
        board = confining(4, in: column(5), to: [cell(1, 5), cell(7, 5)], on: board)
        #expect(EmptyRectangle().findStep(in: board) == nil)
    }

    // MARK: Simple Coloring

    @Test func simpleColoringTrap() throws {
        // Strong links on 6: r0c0-r0c4 (row 0), r0c4-r5c4 (column 4), r5c4-r5c1 (row 5).
        var board = confining(6, in: row(0), to: [cell(0, 0), cell(0, 4)])
        board = confining(6, in: column(4), to: [cell(0, 4), cell(5, 4)], on: board)
        board = confining(6, in: row(5), to: [cell(5, 4), cell(5, 1)], on: board)

        let step = try #require(SimpleColoring().findStep(in: board))
        #expect(step.technique == .simpleColoring)
        #expect(step.patternCells == [cell(0, 0), cell(0, 4), cell(5, 4), cell(5, 1)])
        // r0c0 and r5c1 have opposite colors; these cells see both.
        #expect(cells(of: step, removing: [6]) == [cell(1, 1), cell(2, 1), cell(3, 0), cell(4, 0)])

        let chain = SimpleColoring.chain(of: 6, startingAt: cell(0, 0), in: board)
        #expect(chain.colorA == [cell(0, 0), cell(5, 4)])
        #expect(chain.colorB == [cell(0, 4), cell(5, 1)])
        #expect(chain.links.count == 3)
    }

    @Test func simpleColoringWrap() throws {
        // A chain r0c0, r0c4, r4c4, r4c1, r1c1: r0c0 and r1c1 get the same color and share box 0.
        var board = confining(6, in: row(0), to: [cell(0, 0), cell(0, 4)])
        board = confining(6, in: column(4), to: [cell(0, 4), cell(4, 4)], on: board)
        board = confining(6, in: row(4), to: [cell(4, 4), cell(4, 1)], on: board)
        board = confining(6, in: column(1), to: [cell(4, 1), cell(1, 1)], on: board)

        let step = try #require(SimpleColoring().findStep(in: board))
        #expect(cells(of: step, removing: [6]) == [cell(0, 0), cell(1, 1), cell(4, 4)])
    }

    // MARK: Unique Rectangle

    @Test func uniqueRectangleType1() throws {
        let board = restricting([
            (cell(0, 0), [1, 2]), (cell(0, 1), [1, 2]), (cell(3, 0), [1, 2]), (cell(3, 1), [1, 2, 5]),
        ])
        let step = try #require(UniqueRectangle(variant: .type1).findStep(in: board))
        #expect(step.technique == .uniqueRectangleType1)
        #expect(step.patternCells.last == cell(3, 1))
        #expect(step.eliminations == [Elimination(cell: cell(3, 1), digits: [1, 2])])
    }

    @Test func noUniqueRectangleAcrossFourBoxes() {
        // Rows 0 and 3, columns 0 and 4: four different boxes, so swapping isn't guaranteed to work.
        let board = restricting([
            (cell(0, 0), [1, 2]), (cell(0, 4), [1, 2]), (cell(3, 0), [1, 2]), (cell(3, 4), [1, 2, 5]),
        ])
        #expect(UniqueRectangle(variant: .type1).findStep(in: board) == nil)
    }

    @Test func uniqueRectangleType2() throws {
        // Floor r0c0, r0c1 = {1,2}; roof r3c0, r3c1 = {1,2,7}.
        let board = restricting([
            (cell(0, 0), [1, 2]), (cell(0, 1), [1, 2]), (cell(3, 0), [1, 2, 7]), (cell(3, 1), [1, 2, 7]),
        ])
        #expect(UniqueRectangle(variant: .type1).findStep(in: board) == nil)

        let step = try #require(UniqueRectangle(variant: .type2).findStep(in: board))
        #expect(step.technique == .uniqueRectangleType2)
        #expect(step.patternCells == [cell(0, 0), cell(0, 1), cell(3, 0), cell(3, 1)])
        // Every cell seeing both roof cells: the rest of row 3 and of box 3.
        let removed = cells(of: step, removing: [7])
        #expect(removed.count == 13)
        #expect(removed.allSatisfy { Geometry.sees($0, cell(3, 0)) && Geometry.sees($0, cell(3, 1)) })
    }

    @Test func uniqueRectangleType4() throws {
        // Floor r0c0, r0c1 = {1,2}; in row 3, 1 fits only in the roof cells r3c0 and r3c1.
        var board = restricting([(cell(0, 0), [1, 2]), (cell(0, 1), [1, 2])])
        board = confining(1, in: row(3), to: [cell(3, 0), cell(3, 1)], on: board)

        let step = try #require(UniqueRectangle(variant: .type4).findStep(in: board))
        #expect(step.technique == .uniqueRectangleType4)
        #expect(step.focusHouses == [row(3)])
        #expect(cells(of: step, removing: [2]) == [cell(3, 0), cell(3, 1)])
    }

    // MARK: BUG+1

    @Test func bugPlusOne() throws {
        // Every empty cell is {4,5} except r0c0 {1,2,3}, r0c1 {3,4} and r0c2 {3,5}: 3 appears three
        // times in box 0.
        var cells: [(CellIndex, CandidateSet)] = Geometry.cells.map { ($0, [4, 5]) }
        cells[0] = (0, [1, 2, 3])
        cells[1] = (1, [3, 4])
        cells[2] = (2, [3, 5])
        let board = restricting(cells)

        let step = try #require(BUG().findStep(in: board))
        #expect(step.technique == .bug)
        #expect(step.placements == [Placement(cell: 0, digit: 3)])
        #expect(step.focusHouses == [box(0)])
    }

    @Test func noBugWithTwoThreeCandidateCells() {
        var cells: [(CellIndex, CandidateSet)] = Geometry.cells.map { ($0, [4, 5]) }
        cells[0] = (0, [1, 2, 3])
        cells[80] = (80, [1, 2, 3])
        #expect(BUG().findStep(in: restricting(cells)) == nil)
    }

    // MARK: Solver integration

    @Test func levelFourTechniques() {
        let levelFour: [TechniqueKind] = [
            .uniqueRectangleType1, .swordfish, .emptyRectangle, .simpleColoring, .finnedXWing,
            .uniqueRectangleType2, .uniqueRectangleType4, .bug, .finnedSwordfish, .jellyfish,
        ]
        #expect(levelFour.allSatisfy { $0.level == 4 })
    }

    @Test(arguments: [3, 12] as [UInt64])
    func expertPuzzlesNeedLevelFourAndEveryStepIsCorrect(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let puzzle = PuzzleGenerator.generate(.expert, using: &generator)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))

        let result = LogicalSolver().solve(Board(values: puzzle.givens))
        #expect(result.isSolved)
        #expect(result.hardestTechnique?.level == 4)
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
