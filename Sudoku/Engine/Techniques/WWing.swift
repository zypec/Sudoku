//
//  WWing.swift
//  Sudoku
//

/// Two cells with the same two candidates {x, y} that don't see each other, connected by a strong
/// link on x: a house where x fits in exactly two cells, one seeing each of them.
///
/// One of the link cells holds x, so the bivalue cell it sees isn't x and must be y. Either way one
/// of the two bivalue cells is y, and any cell that sees both can't be y.
///
/// `patternCells` are ordered `[cell1, cell2, link1, link2]`, where `link1` sees `cell1` and `link2`
/// sees `cell2`. `focusHouses` is the link's house. The eliminated digit is y; the other is x.
struct WWing: Technique {
    let kind = TechniqueKind.wWing

    func findStep(in board: Board) -> SolveStep? {
        let bivalueCells = Geometry.cells.filter { board.candidates(at: $0).count == 2 }

        for pair in bivalueCells.combinations(ofSize: 2) {
            let (cell1, cell2) = (pair[0], pair[1])
            let digits = board.candidates(at: cell1)
            // Cells that see each other would be a naked pair instead.
            guard board.candidates(at: cell2) == digits, !Geometry.sees(cell1, cell2) else { continue }

            for linkDigit in digits {
                let eliminated = digits.subtracting([linkDigit])
                guard let y = eliminated.single else { continue }
                let eliminations = board.eliminations(of: y, from: Geometry.cellsSeeingAll([cell1, cell2]))
                guard !eliminations.isEmpty,
                      let (house, link1, link2) = strongLink(on: linkDigit, connecting: cell1, cell2, in: board)
                else { continue }

                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    focusHouses: [house],
                    patternCells: [cell1, cell2, link1, link2],
                    patternDigits: digits
                )
            }
        }
        return nil
    }

    /// A house where `digit` fits in exactly two cells, neither of them `cell1` or `cell2`, one
    /// seeing `cell1` and the other seeing `cell2`. Returns the link cells in that order.
    private func strongLink(
        on digit: Digit,
        connecting cell1: CellIndex,
        _ cell2: CellIndex,
        in board: Board
    ) -> (House, CellIndex, CellIndex)? {
        for house in Geometry.houses {
            let cells = board.cells(in: house, withCandidate: digit)
            guard cells.count == 2, !cells.contains(cell1), !cells.contains(cell2) else { continue }
            if Geometry.sees(cells[0], cell1) && Geometry.sees(cells[1], cell2) {
                return (house, cells[0], cells[1])
            }
            if Geometry.sees(cells[1], cell1) && Geometry.sees(cells[0], cell2) {
                return (house, cells[1], cells[0])
            }
        }
        return nil
    }
}
