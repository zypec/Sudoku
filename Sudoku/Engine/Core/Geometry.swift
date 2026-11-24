//
//  Geometry.swift
//  Sudoku
//

/// Index of a cell on the board, `0..<81`, laid out row by row (`row * 9 + column`).
typealias CellIndex = Int

/// A Sudoku digit, `1...9`. Value arrays use `0` for an empty cell.
typealias Digit = Int

/// One of the 27 groups of nine cells (box, row or column) that must contain every digit exactly once.
struct House: Hashable, Sendable, Codable {
    /// Declaration order is also the default scan order for techniques: players usually
    /// spot patterns inside boxes before rows and columns.
    enum Kind: Int, CaseIterable, Sendable, Codable {
        case box, row, column
    }

    let kind: Kind
    /// `0..<9`. Boxes are numbered left to right, top to bottom.
    let index: Int

    var cells: [CellIndex] {
        Geometry.cellsByHouse[kind.rawValue * 9 + index]
    }

    func contains(_ cell: CellIndex) -> Bool {
        switch kind {
        case .box: Geometry.box(of: cell) == index
        case .row: Geometry.row(of: cell) == index
        case .column: Geometry.column(of: cell) == index
        }
    }
}

/// Precomputed board geometry shared by every part of the engine.
enum Geometry {
    static let digits: ClosedRange<Digit> = 1...9
    static let cellCount = 81
    static let cells: Range<CellIndex> = 0..<81

    static func row(of cell: CellIndex) -> Int { cell / 9 }
    static func column(of cell: CellIndex) -> Int { cell % 9 }
    static func box(of cell: CellIndex) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }
    static func cell(row: Int, column: Int) -> CellIndex { row * 9 + column }

    /// All 27 houses in scan order: boxes, then rows, then columns.
    static let houses: [House] = House.Kind.allCases.flatMap { kind in
        (0..<9).map { House(kind: kind, index: $0) }
    }

    /// The box, row and column that contain `cell`, in that order.
    static func houses(containing cell: CellIndex) -> [House] {
        [
            House(kind: .box, index: box(of: cell)),
            House(kind: .row, index: row(of: cell)),
            House(kind: .column, index: column(of: cell)),
        ]
    }

    /// The 20 other cells that share a house with each cell.
    static let peers: [[CellIndex]] = cells.map { cell in
        cells.filter { sees(cell, $0) }
    }

    /// Whether two distinct cells share a box, row or column.
    static func sees(_ a: CellIndex, _ b: CellIndex) -> Bool {
        a != b && (row(of: a) == row(of: b) || column(of: a) == column(of: b) || box(of: a) == box(of: b))
    }

    /// Cells, other than the given ones, that see every cell in `cells`. Used by patterns that
    /// prove "one of these cells holds the digit": any cell seeing all of them can't hold it.
    static func cellsSeeingAll(_ cells: [CellIndex]) -> [CellIndex] {
        guard let first = cells.first else { return [] }
        return peers[first].filter { candidate in
            !cells.contains(candidate) && cells.allSatisfy { sees(candidate, $0) }
        }
    }

    /// Cells of every house, indexed by `kind.rawValue * 9 + index`.
    fileprivate static let cellsByHouse: [[CellIndex]] = House.Kind.allCases.flatMap { kind in
        (0..<9).map { index in
            (0..<9).map { position in
                switch kind {
                case .box:
                    (index / 3) * 27 + (index % 3) * 3 + (position / 3) * 9 + position % 3
                case .row:
                    index * 9 + position
                case .column:
                    position * 9 + index
                }
            }
        }
    }
}
