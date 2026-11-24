//
//  BruteForceSolver.swift
//  Sudoku
//

/// Fast backtracking solver used only to verify puzzles (uniqueness) and to look up solutions.
///
/// It never explains anything — hints and difficulty grading use `LogicalSolver` instead.
enum BruteForceSolver {
    /// Counts solutions of `values` (81 digits, `0` = empty), stopping once `limit` is reached.
    /// Returns `0` for grids whose givens already conflict.
    static func countSolutions(of values: [Digit], limit: Int = 2) -> Int {
        guard var search = Search(values: values, limit: limit) else { return 0 }
        search.run()
        return search.solutionCount
    }

    /// Whether `values` has exactly one solution.
    static func hasUniqueSolution(_ values: [Digit]) -> Bool {
        countSolutions(of: values, limit: 2) == 1
    }

    /// The first solution found, or `nil` if there is none.
    static func solution(of values: [Digit]) -> [Digit]? {
        guard var search = Search(values: values, limit: 1) else { return nil }
        search.run()
        return search.firstSolution
    }
}

/// Depth-first search over digit bitmasks. At every level it branches on the empty cell with the
/// fewest options ("minimum remaining values"), which keeps the tree tiny for real puzzles.
private struct Search {
    private var values: [Digit]
    /// Digits already used in each row, column and box (bit `d` = digit `d`).
    private var rowMasks = [UInt16](repeating: 0, count: 9)
    private var columnMasks = [UInt16](repeating: 0, count: 9)
    private var boxMasks = [UInt16](repeating: 0, count: 9)
    private let limit: Int

    private(set) var solutionCount = 0
    private(set) var firstSolution: [Digit]?

    private static let allDigits: UInt16 = 0b11_1111_1110

    /// Fails when the givens break the one-digit-per-house rule.
    init?(values: [Digit], limit: Int) {
        precondition(values.count == Geometry.cellCount, "A board needs 81 values")
        self.values = values
        self.limit = max(1, limit)
        for cell in Geometry.cells where values[cell] != 0 {
            let bit: UInt16 = 1 << values[cell]
            let (row, column, box) = Self.houseIndices(of: cell)
            guard (rowMasks[row] | columnMasks[column] | boxMasks[box]) & bit == 0 else { return nil }
            rowMasks[row] |= bit
            columnMasks[column] |= bit
            boxMasks[box] |= bit
        }
    }

    mutating func run() {
        // Pick the most constrained empty cell.
        var bestCell = -1
        var bestOptions: UInt16 = 0
        var bestCount = 10
        for cell in Geometry.cells where values[cell] == 0 {
            let options = self.options(for: cell)
            let count = options.nonzeroBitCount
            if count < bestCount {
                bestCell = cell
                bestOptions = options
                bestCount = count
                if count <= 1 { break }
            }
        }

        guard bestCell >= 0 else {
            // No empty cell left: this is a solution.
            solutionCount += 1
            if firstSolution == nil {
                firstSolution = values
            }
            return
        }

        let (row, column, box) = Self.houseIndices(of: bestCell)
        var remaining = bestOptions
        while remaining != 0 {
            let digit = remaining.trailingZeroBitCount
            remaining &= remaining - 1
            let bit: UInt16 = 1 << digit

            values[bestCell] = digit
            rowMasks[row] |= bit
            columnMasks[column] |= bit
            boxMasks[box] |= bit

            run()

            values[bestCell] = 0
            rowMasks[row] &= ~bit
            columnMasks[column] &= ~bit
            boxMasks[box] &= ~bit

            if solutionCount >= limit { return }
        }
    }

    private func options(for cell: CellIndex) -> UInt16 {
        let (row, column, box) = Self.houseIndices(of: cell)
        return Self.allDigits & ~(rowMasks[row] | columnMasks[column] | boxMasks[box])
    }

    private static func houseIndices(of cell: CellIndex) -> (row: Int, column: Int, box: Int) {
        (Geometry.row(of: cell), Geometry.column(of: cell), Geometry.box(of: cell))
    }
}
