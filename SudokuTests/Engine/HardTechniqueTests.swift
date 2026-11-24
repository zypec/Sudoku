//
//  HardTechniqueTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

/// Level 3 patterns. Like the intermediate tests, positions are built on an empty board by
/// eliminating candidates, so each test isolates exactly the pattern it checks.
@Suite("Hard techniques")
struct HardTechniqueTests {
    /// Removes `digits` from every cell in `cells`.
    private func eliminating(_ digits: CandidateSet, from cells: some Sequence<CellIndex>, on board: Board = Board()) -> Board {
        var board = board
        for cell in cells {
            board.eliminate(digits, from: cell)
        }
        return board
    }

    /// Leaves `digit` only in `keep` within `house`.
    private func confining(_ digit: Digit, in house: House, to keep: [CellIndex], on board: Board = Board()) -> Board {
        eliminating([digit], from: house.cells.filter { !keep.contains($0) }, on: board)
    }

    /// Leaves exactly `candidates` in each cell.
    private func restricting(_ cells: [(CellIndex, CandidateSet)], on board: Board = Board()) -> Board {
        var board = board
        for (cell, candidates) in cells {
            board.eliminate(CandidateSet.all.subtracting(candidates), from: cell)
        }
        return board
    }

    private func cell(_ row: Int, _ column: Int) -> CellIndex {
        Geometry.cell(row: row, column: column)
    }

    private func row(_ index: Int) -> House { House(kind: .row, index: index) }
    private func column(_ index: Int) -> House { House(kind: .column, index: index) }
    private func box(_ index: Int) -> House { House(kind: .box, index: index) }

    /// Every elimination removes exactly `digit`; returns the affected cells, sorted.
    private func cells(of step: SolveStep, removing digit: Digit) -> [CellIndex] {
        #expect(step.placements.isEmpty)
        #expect(step.eliminations.allSatisfy { $0.digits == [digit] })
        return step.eliminations.map(\.cell).sorted()
    }

    // MARK: Geometry helper

    @Test func cellsSeeingAllExcludesTheGivenCells() {
        // r0c0 and r0c8 share only row 0.
        #expect(Geometry.cellsSeeingAll([cell(0, 0), cell(0, 8)]) == Array(1...7))
        // Cells in different rows, columns and boxes are seen together only at the two crossings.
        #expect(Geometry.cellsSeeingAll([cell(0, 0), cell(4, 4)]) == [cell(0, 4), cell(4, 0)])
    }

    // MARK: X-Wing

    @Test func xWingAlongRows() throws {
        // Rows 1 and 4 hold 5 only in columns 2 and 6.
        var board = confining(5, in: row(1), to: [cell(1, 2), cell(1, 6)])
        board = confining(5, in: row(4), to: [cell(4, 2), cell(4, 6)], on: board)

        let step = try #require(BasicFish.xWing.findStep(in: board))
        #expect(step.technique == .xWing)
        #expect(step.focusHouses == [row(1), row(4), column(2), column(6)])
        #expect(step.patternCells == [cell(1, 2), cell(1, 6), cell(4, 2), cell(4, 6)])
        let expected = [0, 2, 3, 5, 6, 7, 8].flatMap { [cell($0, 2), cell($0, 6)] }.sorted()
        #expect(cells(of: step, removing: 5) == expected)
    }

    @Test func xWingAlongColumns() throws {
        // Columns 0 and 7 hold 8 only in rows 3 and 5.
        var board = confining(8, in: column(0), to: [cell(3, 0), cell(5, 0)])
        board = confining(8, in: column(7), to: [cell(3, 7), cell(5, 7)], on: board)

        let step = try #require(BasicFish.xWing.findStep(in: board))
        #expect(step.focusHouses == [column(0), column(7), row(3), row(5)])
        let expected = [1, 2, 3, 4, 5, 6, 8].flatMap { [cell(3, $0), cell(5, $0)] }.sorted()
        #expect(cells(of: step, removing: 8) == expected)
    }

    @Test func noXWingWhenTheCoverLinesAreAlreadyClear() {
        var board = confining(5, in: row(1), to: [cell(1, 2), cell(1, 6)])
        board = confining(5, in: row(4), to: [cell(4, 2), cell(4, 6)], on: board)
        board = confining(5, in: column(2), to: [cell(1, 2), cell(4, 2)], on: board)
        board = confining(5, in: column(6), to: [cell(1, 6), cell(4, 6)], on: board)
        #expect(BasicFish.xWing.findStep(in: board) == nil)
    }

    @Test func noXWingWhenTheRowsUseThreeColumns() {
        var board = confining(5, in: row(1), to: [cell(1, 2), cell(1, 6)])
        board = confining(5, in: row(4), to: [cell(4, 2), cell(4, 7)], on: board)
        #expect(BasicFish.xWing.findStep(in: board) == nil)
    }

    // MARK: Skyscraper

    @Test func skyscraper() throws {
        // Rows 1 and 6 hold 3 in two cells each; the base is column 0, the tops are r1c3 and r6c5.
        var board = confining(3, in: row(1), to: [cell(1, 0), cell(1, 3)])
        board = confining(3, in: row(6), to: [cell(6, 0), cell(6, 5)], on: board)
        #expect(BasicFish.xWing.findStep(in: board) == nil)

        let step = try #require(Skyscraper().findStep(in: board))
        #expect(step.technique == .skyscraper)
        #expect(step.patternCells == [cell(1, 3), cell(6, 5), cell(1, 0), cell(6, 0)])
        #expect(step.focusHouses == [row(1), row(6), column(0)])
        // Cells seeing both tops: column 3 inside box 7, and column 5 inside box 1.
        #expect(cells(of: step, removing: 3) == [cell(0, 5), cell(2, 5), cell(7, 3), cell(8, 3)].sorted())
    }

    @Test func noSkyscraperWithoutASharedBase() {
        var board = confining(3, in: row(1), to: [cell(1, 0), cell(1, 3)])
        board = confining(3, in: row(6), to: [cell(6, 1), cell(6, 5)], on: board)
        #expect(Skyscraper().findStep(in: board) == nil)
    }

    // MARK: 2-String Kite

    @Test func twoStringKite() throws {
        // Row 0 holds 4 in r0c1 and r0c6; column 0 holds it in r2c0 and r7c0. r0c1 and r2c0 share box 0.
        var board = confining(4, in: row(0), to: [cell(0, 1), cell(0, 6)])
        board = confining(4, in: column(0), to: [cell(2, 0), cell(7, 0)], on: board)

        let step = try #require(TwoStringKite().findStep(in: board))
        #expect(step.technique == .twoStringKite)
        #expect(step.patternCells == [cell(0, 6), cell(7, 0), cell(0, 1), cell(2, 0)])
        #expect(step.focusHouses == [row(0), column(0), box(0)])
        #expect(cells(of: step, removing: 4) == [cell(7, 6)])
    }

    @Test func noKiteWhenTheStringsMeetOutsideABox() {
        var board = confining(4, in: row(0), to: [cell(0, 1), cell(0, 6)])
        board = confining(4, in: column(0), to: [cell(4, 0), cell(7, 0)], on: board)
        #expect(TwoStringKite().findStep(in: board) == nil)
    }

    // MARK: XY-Wing

    @Test func xyWing() throws {
        // Pivot r0c0 {1,2}, pincers r0c4 {1,3} and r2c0 {2,3}.
        let board = restricting([(cell(0, 0), [1, 2]), (cell(0, 4), [1, 3]), (cell(2, 0), [2, 3])])

        let step = try #require(XYWing().findStep(in: board))
        #expect(step.technique == .xyWing)
        #expect(step.patternCells == [cell(0, 0), cell(0, 4), cell(2, 0)])
        #expect(step.patternDigits == [1, 2, 3])
        #expect(step.focusHouses.isEmpty)
        // Cells seeing both pincers: row 0 inside box 0, and row 2 inside box 1.
        #expect(cells(of: step, removing: 3) == [cell(0, 1), cell(0, 2), cell(2, 3), cell(2, 4), cell(2, 5)])
    }

    @Test func noXYWingWhenThePincersShareTheSamePivotDigit() {
        let board = restricting([(cell(0, 0), [1, 2]), (cell(0, 4), [1, 3]), (cell(2, 0), [1, 3])])
        #expect(XYWing().findStep(in: board) == nil)
    }

    // MARK: XYZ-Wing

    @Test func xyzWing() throws {
        // Pivot r0c0 {1,2,3}, pincers r0c1 {1,3} and r3c0 {2,3}.
        let board = restricting([(cell(0, 0), [1, 2, 3]), (cell(0, 1), [1, 3]), (cell(3, 0), [2, 3])])
        #expect(XYWing().findStep(in: board) == nil)

        let step = try #require(XYZWing().findStep(in: board))
        #expect(step.technique == .xyzWing)
        #expect(step.patternCells == [cell(0, 0), cell(0, 1), cell(3, 0)])
        #expect(step.patternDigits == [1, 2, 3])
        // Only column 0 inside box 0 sees all three cells.
        #expect(cells(of: step, removing: 3) == [cell(1, 0), cell(2, 0)])
    }

    // MARK: W-Wing

    @Test func wWing() throws {
        // r0c0 and r4c4 are {1,2}; column 8 holds 1 only in r0c8 (sees r0c0) and r4c8 (sees r4c4).
        var board = restricting([(cell(0, 0), [1, 2]), (cell(4, 4), [1, 2])])
        board = confining(1, in: column(8), to: [cell(0, 8), cell(4, 8)], on: board)

        let step = try #require(WWing().findStep(in: board))
        #expect(step.technique == .wWing)
        #expect(step.patternCells == [cell(0, 0), cell(4, 4), cell(0, 8), cell(4, 8)])
        #expect(step.focusHouses == [column(8)])
        #expect(cells(of: step, removing: 2) == [cell(0, 4), cell(4, 0)])
    }

    @Test func noWWingWithoutAStrongLink() {
        let board = restricting([(cell(0, 0), [1, 2]), (cell(4, 4), [1, 2])])
        #expect(WWing().findStep(in: board) == nil)
    }

    // MARK: Published examples

    /// Example puzzles from sudokuwiki.org's strategy pages, with the technique we expect the solver
    /// to need and whether our current technique set can finish them.
    @Test(arguments: [
        ("100000569402000008050009040000640801000010000208035000040500010900000402621000005", TechniqueKind.xWing, true),
        ("000001008700030009020000061080009003001040900900300020240000080600090005100600000", .twoStringKite, true),
        ("034500000802060400600008000003900004050000090900005800000300008001040605000007120", .skyscraper, true),
        ("090001700500200008000030200070004960200060005069700030008090000700003009003800040", .xyzWing, false),
        ("900000000037010420840000603000034810000060000068120000102000084085070360000000001", .xyWing, true),
    ])
    func publishedExamplesAreSolvedSoundly(puzzle: String, technique: TechniqueKind, isSolvable: Bool) throws {
        let board = try TestPuzzles.board(puzzle)
        let solution = try #require(BruteForceSolver.solution(of: board.values))
        let result = LogicalSolver().solve(board)

        #expect(result.isSolved == isSolvable)
        #expect(result.steps.contains { $0.technique == technique })
        for step in result.steps {
            for placement in step.placements {
                #expect(solution[placement.cell] == placement.digit, "\(step.technique) placed a wrong digit")
            }
            for elimination in step.eliminations {
                #expect(!elimination.digits.contains(solution[elimination.cell]), "\(step.technique) removed the solution")
            }
        }
    }

    // MARK: Solver integration

    @Test func levelThreeTechniques() {
        let levelThree: [TechniqueKind] = [.nakedQuad, .hiddenQuad, .xWing, .skyscraper, .twoStringKite, .xyWing, .xyzWing, .wWing]
        #expect(levelThree.allSatisfy { $0.level == 3 })
    }

    @Test(arguments: [1, 2, 3] as [UInt64])
    func hardPuzzlesNeedLevelThreeAndEveryStepIsCorrect(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let puzzle = PuzzleGenerator.generate(.hard, using: &generator)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))

        let result = LogicalSolver().solve(Board(values: puzzle.givens))
        #expect(result.isSolved)
        #expect(result.hardestTechnique?.level == 3)
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
