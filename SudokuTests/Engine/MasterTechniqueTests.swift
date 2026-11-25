//
//  MasterTechniqueTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

/// Level 5 patterns (chains and almost locked sets), built on an empty board by eliminating
/// candidates so each test isolates exactly the pattern it checks.
@Suite("Master techniques")
struct MasterTechniqueTests {
    private func cell(_ row: Int, _ column: Int) -> CellIndex {
        Geometry.cell(row: row, column: column)
    }

    private func node(_ row: Int, _ column: Int, _ digit: Digit) -> ChainNode {
        ChainNode(cell: cell(row, column), digit: digit)
    }

    private func row(_ index: Int) -> House { House(kind: .row, index: index) }
    private func column(_ index: Int) -> House { House(kind: .column, index: index) }

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

    private func eliminated(_ step: SolveStep) -> [CellIndex] {
        step.eliminations.map(\.cell).sorted()
    }

    // MARK: Remote Pair

    @Test func remotePair() throws {
        // Four {1,2} cells, each seeing the next: r1c1, r1c5, r5c5, r5c9.
        let chain = [cell(0, 0), cell(0, 4), cell(4, 4), cell(4, 8)]
        let board = restricting(chain.map { ($0, [1, 2]) })

        let step = try #require(RemotePair().findStep(in: board))
        #expect(step.technique == .remotePair)
        #expect(step.patternCells == chain)
        #expect(step.patternDigits == [1, 2])
        // The ends hold different digits; the two cells seeing both lose 1 and 2.
        #expect(step.eliminations == [Elimination(cell: cell(0, 8), digits: [1, 2]), Elimination(cell: cell(4, 0), digits: [1, 2])])
    }

    @Test func noRemotePairWithEvenDistance() {
        // Three cells: the ends are two steps apart and hold the same digit.
        let board = restricting([cell(0, 0), cell(0, 4), cell(4, 4)].map { ($0, [1, 2]) })
        #expect(RemotePair().findStep(in: board) == nil)
    }

    // MARK: X-Chain

    @Test func xChain() throws {
        // The skyscraper position on 3: r2c4 = r2c1 - r7c1 = r7c6.
        var board = confining(3, in: row(1), to: [cell(1, 0), cell(1, 3)])
        board = confining(3, in: row(6), to: [cell(6, 0), cell(6, 5)], on: board)

        let step = try #require(XChain().findStep(in: board))
        #expect(step.technique == .xChain)
        #expect(step.chain == [node(1, 3, 3), node(1, 0, 3), node(6, 0, 3), node(6, 5, 3)])
        #expect(step.eliminations.allSatisfy { $0.digits == [3] })
        #expect(eliminated(step) == [cell(0, 5), cell(2, 5), cell(7, 3), cell(8, 3)].sorted())
    }

    // MARK: XY-Chain

    @Test func xyChain() throws {
        // {1,2} - {2,3} - {3,4} - {4,1}: the first and last cells can't both lack 1.
        let board = restricting([
            (cell(0, 0), [1, 2]), (cell(0, 4), [2, 3]), (cell(4, 4), [3, 4]), (cell(4, 8), [1, 4]),
        ])
        #expect(XYWing().findStep(in: board) == nil)

        let step = try #require(XYChain().findStep(in: board))
        #expect(step.technique == .xyChain)
        #expect(step.chain.first == node(0, 0, 1))
        #expect(step.chain.last == node(4, 8, 1))
        #expect(step.chain.count == 8)
        #expect(step.eliminations == [Elimination(cell: cell(0, 8), digits: [1]), Elimination(cell: cell(4, 0), digits: [1])])
    }

    // MARK: AIC

    @Test func aicMixesCellAndHouseLinks() throws {
        // r1c1 is {1,2}; column 5 holds 2 only in r1c5 and r6c5; row 6 holds 1 only in r6c5 and r6c1.
        // Chain: 1r1c1 = 2r1c1 - 2r1c5 = 2r6c5 - 1r6c5 = 1r6c1, so 1 is in r1c1 or r6c1.
        var board = restricting([(cell(0, 0), [1, 2])])
        board = confining(2, in: column(4), to: [cell(0, 4), cell(5, 4)], on: board)
        board = confining(1, in: row(5), to: [cell(5, 4), cell(5, 0)], on: board)
        #expect(XChain().findStep(in: board) == nil)
        #expect(XYChain().findStep(in: board) == nil)

        let step = try #require(AIC().findStep(in: board))
        #expect(step.technique == .aic)
        #expect(step.chain == [node(0, 0, 1), node(0, 0, 2), node(0, 4, 2), node(5, 4, 2), node(5, 4, 1), node(5, 0, 1)])
        #expect(step.eliminations.allSatisfy { $0.digits == [1] })
        // Column 1 apart from the two ends.
        #expect(eliminated(step) == [1, 2, 3, 4, 6, 7, 8].map { cell($0, 0) })
    }

    @Test func chainEndsInOneCellClearTheCell() {
        // Both ends in one cell: its other candidates go.
        var board = Board()
        board.eliminate([5], from: 0)
        let search = ChainSearch(board: board, scope: .all)
        let eliminations = search.eliminations(between: node(0, 0, 1), and: node(0, 0, 2))
        #expect(eliminations == [Elimination(cell: 0, digits: [3, 4, 6, 7, 8, 9])])
    }

    @Test func chainEndsWithDifferentDigitsInSeeingCells() {
        // 1 at r1c1 or 2 at r1c2, and the cells see each other.
        let search = ChainSearch(board: Board(), scope: .all)
        let eliminations = search.eliminations(between: node(0, 0, 1), and: node(0, 1, 2))
        #expect(eliminations == [Elimination(cell: cell(0, 0), digits: [2]), Elimination(cell: cell(0, 1), digits: [1])])
        #expect(search.eliminations(between: node(0, 0, 1), and: node(4, 4, 2)).isEmpty)
    }

    // MARK: ALS-XZ

    @Test func alsXZ() throws {
        // A = r3c3 {1,3}; B = r2c2 {2,3} and r2c6 {1,2} in row 2. They share 3 (r3c3 sees r2c2), so
        // 3 is in at most one of them, and 1 is in at least one.
        let board = restricting([(cell(1, 1), [2, 3]), (cell(2, 2), [1, 3]), (cell(1, 5), [1, 2])])

        let step = try #require(ALSXZ().findStep(in: board))
        #expect(step.technique == .alsXZ)
        #expect(step.cellGroups == [[cell(2, 2)], [cell(1, 1), cell(1, 5)]])
        #expect(step.patternDigits == [1, 3])
        #expect(step.eliminations.allSatisfy { $0.digits == [1] })
        #expect(eliminated(step) == [cell(1, 0), cell(1, 2), cell(2, 3), cell(2, 4), cell(2, 5)])
    }

    // MARK: Solver integration

    @Test func levelFiveTechniques() {
        let levelFive: [TechniqueKind] = [.remotePair, .xChain, .xyChain, .aic, .alsXZ]
        #expect(levelFive.allSatisfy { $0.level == 5 })
        #expect(PuzzleGenerator.supportedDifficulties == Set(Difficulty.allCases))
    }

    @Test(arguments: [1, 2] as [UInt64])
    func masterPuzzlesNeedLevelFiveAndEveryStepIsCorrect(seed: UInt64) {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let puzzle = PuzzleGenerator.generate(.master, using: &generator)
        #expect(BruteForceSolver.hasUniqueSolution(puzzle.givens))

        let result = LogicalSolver().solve(Board(values: puzzle.givens))
        #expect(result.isSolved)
        #expect(result.hardestTechnique?.level == 5)
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
