//
//  BUG.swift
//  Sudoku
//

/// BUG+1 (Bivalue Universal Grave plus one). Relies on the puzzle having a single solution.
///
/// If every empty cell had exactly two candidates and each candidate appeared exactly twice in every
/// house, the position would have two solutions (a "bivalue universal grave"). When all empty cells
/// but one are bivalue and that one has three candidates, the extra candidate there, the one that
/// appears three times in its houses, must be the solution of that cell.
///
/// `patternCells` is the three-candidate cell; `focusHouses` is the house where the digit appears
/// three times.
struct BUG: Technique {
    let kind = TechniqueKind.bug

    func findStep(in board: Board) -> SolveStep? {
        let empty = board.emptyCells
        let trivalue = empty.filter { board.candidates(at: $0).count == 3 }
        guard trivalue.count == 1, let cell = trivalue.first,
              empty.allSatisfy({ $0 == cell || board.candidates(at: $0).count == 2 })
        else { return nil }

        for house in Geometry.houses(containing: cell) {
            for digit in board.candidates(at: cell) where board.cells(in: house, withCandidate: digit).count == 3 {
                return SolveStep(
                    technique: kind,
                    placements: [Placement(cell: cell, digit: digit)],
                    focusHouses: [house],
                    patternCells: [cell],
                    patternDigits: [digit]
                )
            }
        }
        return nil
    }
}
