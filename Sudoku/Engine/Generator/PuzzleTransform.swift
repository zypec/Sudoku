//
//  PuzzleTransform.swift
//  Sudoku
//

/// A symmetry of the Sudoku rules: relabel the digits, reorder rows within their band and the bands
/// themselves, do the same for columns, and optionally transpose. A transformed puzzle has the same
/// logic (same techniques, same difficulty) but looks like a different puzzle, so one stored puzzle
/// can be played many times.
struct PuzzleTransform: Hashable, Sendable {
    /// `digits[d]` replaces digit `d`; `digits[0]` is always 0 (empty).
    let digits: [Digit]
    /// Row `r` of the result is row `rows[r]` of the original.
    let rows: [Int]
    /// Column `c` of the result is column `columns[c]` of the original.
    let columns: [Int]
    /// Whether rows and columns are swapped after reordering.
    let transposes: Bool

    static let identity = PuzzleTransform(digits: Array(0...9), rows: Array(0..<9), columns: Array(0..<9), transposes: false)

    /// A random symmetry. Uses only `stableShuffle`, so the same generator state gives the same
    /// transform on every device (the daily puzzle relies on this).
    static func random(using generator: inout some RandomNumberGenerator) -> PuzzleTransform {
        var relabeling = Array(Geometry.digits)
        relabeling.stableShuffle(using: &generator)
        return PuzzleTransform(
            digits: [0] + relabeling,
            rows: lineOrder(using: &generator),
            columns: lineOrder(using: &generator),
            transposes: generator.stableIndex(below: 2) == 1
        )
    }

    /// Shuffles the three bands (or stacks), then the three lines inside each.
    private static func lineOrder(using generator: inout some RandomNumberGenerator) -> [Int] {
        var bands = [0, 1, 2]
        bands.stableShuffle(using: &generator)
        return bands.flatMap { band in
            var lines = [0, 1, 2]
            lines.stableShuffle(using: &generator)
            return lines.map { band * 3 + $0 }
        }
    }

    /// Applies the transform to 81 values (`0` stays empty).
    func apply(to values: [Digit]) -> [Digit] {
        Geometry.cells.map { cell in
            var row = Geometry.row(of: cell)
            var column = Geometry.column(of: cell)
            if transposes {
                swap(&row, &column)
            }
            return digits[values[Geometry.cell(row: rows[row], column: columns[column])]]
        }
    }

    /// Applies the transform to 81 candidate sets: cells move like values, digits are relabeled.
    func apply(toCandidates candidates: [CandidateSet]) -> [CandidateSet] {
        Geometry.cells.map { cell in
            var row = Geometry.row(of: cell)
            var column = Geometry.column(of: cell)
            if transposes {
                swap(&row, &column)
            }
            return CandidateSet(candidates[Geometry.cell(row: rows[row], column: columns[column])].map { digits[$0] })
        }
    }

    func apply(to puzzle: Puzzle) -> Puzzle {
        Puzzle(
            givens: apply(to: puzzle.givens),
            solution: apply(to: puzzle.solution),
            difficulty: puzzle.difficulty,
            estimatedSeconds: puzzle.estimatedSeconds,
            requiredTechniques: puzzle.requiredTechniques
        )
    }
}
