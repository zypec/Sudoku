//
//  TestPuzzles.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

/// Well-known puzzles with verified solutions, shared by engine tests.
enum TestPuzzles {
    /// Classic Wikipedia example; solvable with singles only.
    static let easy = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    static let easySolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    /// Arto Inkala's puzzle; unique solution but no singles available at the start.
    static let inkala = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"
    static let inkalaSolution = "812753649943682175675491283154237896369845721287169534521974368438526917796318452"

    /// Inkala's puzzle with its last two rows altered so it has more than one solution.
    static let multipleSolutions = "800000000003600000070090200050007000000045700000100030001000068000000009000000400"

    static func board(_ string: String) throws -> Board {
        try #require(Board(string: string))
    }

    static func values(_ string: String) throws -> [Digit] {
        try board(string).values
    }
}
