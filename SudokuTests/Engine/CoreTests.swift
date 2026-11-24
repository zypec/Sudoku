//
//  CoreTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@Suite("Geometry")
struct GeometryTests {
    @Test func thereAre27HousesOfNineDistinctCells() {
        #expect(Geometry.houses.count == 27)
        for house in Geometry.houses {
            #expect(Set(house.cells).count == 9)
        }
    }

    @Test func everyCellBelongsToExactlyOneHouseOfEachKind() {
        for cell in Geometry.cells {
            for kind in House.Kind.allCases {
                let matches = Geometry.houses.filter { $0.kind == kind && $0.cells.contains(cell) }
                #expect(matches.count == 1)
            }
        }
    }

    @Test func housesContainingReturnsBoxRowColumn() {
        // Row 4, column 7 lies in box 5.
        let cell = Geometry.cell(row: 4, column: 7)
        #expect(Geometry.houses(containing: cell) == [
            House(kind: .box, index: 5),
            House(kind: .row, index: 4),
            House(kind: .column, index: 7),
        ])
    }

    @Test func everyCellHas20PeersExcludingItself() {
        for cell in Geometry.cells {
            let peers = Geometry.peers[cell]
            #expect(peers.count == 20)
            #expect(!peers.contains(cell))
            #expect(peers.allSatisfy { Geometry.sees(cell, $0) })
        }
    }
}

@Suite("CandidateSet")
struct CandidateSetTests {
    @Test func insertRemoveAndContains() {
        var set = CandidateSet()
        set.insert(3)
        set.insert(9)
        #expect(set.contains(3))
        #expect(set.contains(9))
        #expect(!set.contains(1))
        #expect(set.count == 2)
        set.remove(3)
        #expect(set == [9])
    }

    @Test func iteratesDigitsInAscendingOrder() {
        let set: CandidateSet = [7, 2, 5]
        #expect(Array(set) == [2, 5, 7])
    }

    @Test func singleIsOnlySetForOneDigit() {
        #expect(CandidateSet([4]).single == 4)
        #expect(CandidateSet([4, 6]).single == nil)
        #expect(CandidateSet.empty.single == nil)
    }

    @Test func setAlgebra() {
        let a: CandidateSet = [1, 2, 3]
        let b: CandidateSet = [3, 4]
        #expect(a.union(b) == [1, 2, 3, 4])
        #expect(a.intersection(b) == [3])
        #expect(a.subtracting(b) == [1, 2])
        #expect(CandidateSet.all.count == 9)
    }

    @Test func outOfRangeDigitsAreIgnored() {
        #expect(!CandidateSet.all.contains(0))
        #expect(!CandidateSet.all.contains(10))
        #expect(CandidateSet(rawValue: 0xFFFF) == .all)
    }
}

@Suite("Board")
struct BoardTests {
    @Test func parsesAndPrintsPuzzleStrings() throws {
        let board = try TestPuzzles.board(TestPuzzles.easy)
        #expect(board.value(at: 0) == 5)
        #expect(board.value(at: 2) == 0)
        #expect(board.stringValue == TestPuzzles.easy.replacingOccurrences(of: "0", with: "."))
    }

    @Test(arguments: [
        "",
        "123",
        String(repeating: "x", count: 81),
        String(repeating: "1", count: 82),
    ])
    func rejectsMalformedStrings(_ string: String) {
        #expect(Board(string: string) == nil)
    }

    @Test func ignoresWhitespaceAndAcceptsDotsAndDashes() throws {
        let spaced = TestPuzzles.easy
            .replacingOccurrences(of: "0", with: ".")
            .enumerated()
            .map { $0.offset % 9 == 8 ? "\($0.element)\n" : String($0.element) }
            .joined()
        let board = try #require(Board(string: spaced))
        #expect(board == (try TestPuzzles.board(TestPuzzles.easy)))
        #expect(Board(string: String(repeating: "-", count: 81)) == Board())
    }

    @Test func derivesCandidatesFromPeers() throws {
        let board = try TestPuzzles.board(TestPuzzles.easy)
        // Row 0 has 5, 3, 7; column 2 has 8; box 0 has 5, 3, 6, 9, 8.
        #expect(board.candidates(at: 2) == [1, 2, 4])
        // Filled cells have no candidates.
        #expect(board.candidates(at: 0).isEmpty)
    }

    @Test func placingADigitRemovesItFromPeers() {
        var board = Board()
        board.place(7, at: 40)
        #expect(board.value(at: 40) == 7)
        #expect(board.candidates(at: 40).isEmpty)
        for peer in Geometry.peers[40] {
            #expect(!board.candidates(at: peer).contains(7))
        }
        // A cell that doesn't see the center keeps 7.
        #expect(board.candidates(at: 0).contains(7))
    }

    @Test func eliminateReportsWhetherSomethingChanged() {
        var board = Board()
        let first = board.eliminate([1, 2], from: 0)
        let second = board.eliminate([1], from: 0)
        #expect(first)
        #expect(!second)
        #expect(board.candidates(at: 0) == [3, 4, 5, 6, 7, 8, 9])
    }

    @Test func detectsConflictsAndContradictions() throws {
        var values = try TestPuzzles.values(TestPuzzles.easy)
        #expect(!Board(values: values).hasConflict)

        values[2] = 5 // second 5 in row 0
        #expect(Board(values: values).hasConflict)
        #expect(Board(values: values).isContradictory)

        var board = Board()
        board.eliminate(.all, from: 10)
        #expect(!board.hasConflict)
        #expect(board.isContradictory)
    }

    @Test func solvedOnlyWhenFullAndConflictFree() throws {
        #expect(try TestPuzzles.board(TestPuzzles.easySolution).isSolved)
        #expect(!(try TestPuzzles.board(TestPuzzles.easy).isSolved))

        var values = try TestPuzzles.values(TestPuzzles.easySolution)
        values.swapAt(0, 1) // still full, but rows/columns now clash
        #expect(!Board(values: values).isSolved)
    }
}
