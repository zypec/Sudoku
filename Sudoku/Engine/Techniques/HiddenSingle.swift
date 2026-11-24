//
//  HiddenSingle.swift
//  Sudoku
//

/// A digit that has only one possible cell left in a house must go there,
/// even if that cell still has other candidates.
struct HiddenSingle: Technique {
    let kind = TechniqueKind.hiddenSingle

    func findStep(in board: Board) -> SolveStep? {
        // Houses are scanned boxes first, which matches how most players look for hidden singles.
        for house in Geometry.houses {
            let cells = house.cells
            for digit in Geometry.digits {
                var position: CellIndex?
                var count = 0
                for cell in cells where board.candidates(at: cell).contains(digit) {
                    count += 1
                    position = cell
                    if count > 1 { break }
                }

                guard count == 1, let cell = position else { continue }
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
