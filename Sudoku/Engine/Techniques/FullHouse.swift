//
//  FullHouse.swift
//  Sudoku
//

/// A house with only one empty cell: that cell gets the single missing digit.
struct FullHouse: Technique {
    let kind = TechniqueKind.fullHouse

    func findStep(in board: Board) -> SolveStep? {
        for house in Geometry.houses {
            var emptyCell: CellIndex?
            var emptyCount = 0
            var present = CandidateSet()
            for cell in house.cells {
                let value = board.value(at: cell)
                if value == 0 {
                    emptyCount += 1
                    emptyCell = cell
                } else {
                    present.insert(value)
                }
            }

            guard emptyCount == 1,
                  let cell = emptyCell,
                  let digit = CandidateSet.all.subtracting(present).single,
                  board.candidates(at: cell).contains(digit)
            else { continue }

            return SolveStep(
                technique: kind,
                placements: [Placement(cell: cell, digit: digit)],
                focusHouses: [house],
                patternCells: [cell],
                patternDigits: [digit]
            )
        }
        return nil
    }
}
