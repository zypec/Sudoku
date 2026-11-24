//
//  NakedSingle.swift
//  Sudoku
//

/// A cell with only one candidate left gets that digit.
struct NakedSingle: Technique {
    let kind = TechniqueKind.nakedSingle

    func findStep(in board: Board) -> SolveStep? {
        for cell in Geometry.cells where board.value(at: cell) == 0 {
            guard let digit = board.candidates(at: cell).single else { continue }
            return SolveStep(
                technique: kind,
                placements: [Placement(cell: cell, digit: digit)],
                focusHouses: Geometry.houses(containing: cell),
                patternCells: [cell],
                patternDigits: [digit]
            )
        }
        return nil
    }
}
