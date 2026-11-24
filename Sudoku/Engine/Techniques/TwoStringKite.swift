//
//  TwoStringKite.swift
//  Sudoku
//

/// A row and a column in which a digit fits in exactly two cells each. One end of the row's pair and
/// one end of the column's pair lie in the same box (as different cells); the other two ends lie
/// outside that box.
///
/// The two cells inside the box see each other, so at most one holds the digit. If one doesn't, the
/// other end of its string must. So at least one of the two outer ends holds the digit, and any cell
/// that sees both can't.
///
/// `patternCells` are ordered `[rowEnd, columnEnd, rowBoxCell, columnBoxCell]`;
/// `focusHouses` are `[row, column, box]`.
struct TwoStringKite: Technique {
    let kind = TechniqueKind.twoStringKite

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            let rowLinks = links(of: digit, kind: .row, in: board)
            let columnLinks = links(of: digit, kind: .column, in: board)

            for (row, rowCells) in rowLinks {
                for (column, columnCells) in columnLinks {
                    for (rowBoxCell, rowEnd) in [(rowCells[0], rowCells[1]), (rowCells[1], rowCells[0])] {
                        for (columnBoxCell, columnEnd) in [(columnCells[0], columnCells[1]), (columnCells[1], columnCells[0])] {
                            let box = Geometry.box(of: rowBoxCell)
                            guard rowBoxCell != columnBoxCell,
                                  Geometry.box(of: columnBoxCell) == box,
                                  Geometry.box(of: rowEnd) != box,
                                  Geometry.box(of: columnEnd) != box
                            else { continue }

                            let eliminations = board.eliminations(of: digit, from: Geometry.cellsSeeingAll([rowEnd, columnEnd]))
                            guard !eliminations.isEmpty else { continue }
                            return SolveStep(
                                technique: kind,
                                eliminations: eliminations,
                                focusHouses: [row, column, House(kind: .box, index: box)],
                                patternCells: [rowEnd, columnEnd, rowBoxCell, columnBoxCell],
                                patternDigits: [digit]
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Lines of `kind` in which `digit` fits in exactly two cells.
    private func links(of digit: Digit, kind: House.Kind, in board: Board) -> [(House, [CellIndex])] {
        (0..<9).compactMap { index in
            let line = House(kind: kind, index: index)
            let cells = board.cells(in: line, withCandidate: digit)
            return cells.count == 2 ? (line, cells) : nil
        }
    }
}
