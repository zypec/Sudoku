//
//  EmptyRectangle.swift
//  Sudoku
//

/// Inside a box, every candidate for a digit lies on one row *and* one column of the box (an L or
/// cross shape, leaving the rest of the box "empty"). So the digit in this box is either in that row
/// or in that column.
///
/// Combine it with a strong link: a line outside the box where the digit fits in exactly two cells,
/// X and Y, with X on one of the box's two lines (the *crossed* line). If X holds the digit, the
/// box's cells on the crossed line can't, so the box's digit is on the other (*kept*) line. If X
/// doesn't, Y does. The cell where the kept line meets Y's line sees both outcomes, so it can't
/// hold the digit.
///
/// `patternCells` are `[X, Y, box cells…]`; `focusHouses` are `[box, linkLine, crossedLine, keptLine]`.
struct EmptyRectangle: Technique {
    let kind = TechniqueKind.emptyRectangle

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            for boxIndex in 0..<9 {
                let box = House(kind: .box, index: boxIndex)
                let boxCells = board.cells(in: box, withCandidate: digit)
                guard boxCells.count >= 2 else { continue }
                let rows = Set(box.cells.map(Geometry.row(of:)))
                let columns = Set(box.cells.map(Geometry.column(of:)))

                for row in rows.sorted() {
                    for column in columns.sorted() {
                        // Every candidate is on the row or the column, and both are really used.
                        guard boxCells.allSatisfy({ Geometry.row(of: $0) == row || Geometry.column(of: $0) == column }),
                              boxCells.contains(where: { Geometry.row(of: $0) == row && Geometry.column(of: $0) != column }),
                              boxCells.contains(where: { Geometry.column(of: $0) == column && Geometry.row(of: $0) != row })
                        else { continue }

                        let rowLine = House(kind: .row, index: row)
                        let columnLine = House(kind: .column, index: column)
                        // A column link crosses the box's row; the box's digit is then kept on its column.
                        if let step = linkStep(digit, box: box, boxCells: boxCells, linkKind: .column, crossed: rowLine, kept: columnLine, in: board) {
                            return step
                        }
                        if let step = linkStep(digit, box: box, boxCells: boxCells, linkKind: .row, crossed: columnLine, kept: rowLine, in: board) {
                            return step
                        }
                    }
                }
            }
        }
        return nil
    }

    private func linkStep(
        _ digit: Digit,
        box: House,
        boxCells: [CellIndex],
        linkKind: House.Kind,
        crossed: House,
        kept: House,
        in board: Board
    ) -> SolveStep? {
        for index in 0..<9 {
            let link = House(kind: linkKind, index: index)
            // The link line must run outside the box.
            guard !box.cells.contains(where: link.contains) else { continue }
            let cells = board.cells(in: link, withCandidate: digit)
            guard cells.count == 2 else { continue }

            for (x, y) in [(cells[0], cells[1]), (cells[1], cells[0])] {
                guard crossed.contains(x) else { continue }
                // The target is where the kept line meets the line through Y, outside the box.
                let target = kept.cells.first { cell in
                    linkKind == .column ? Geometry.row(of: cell) == Geometry.row(of: y) : Geometry.column(of: cell) == Geometry.column(of: y)
                }
                guard let target, !box.contains(target), board.candidates(at: target).contains(digit) else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: [Elimination(cell: target, digits: [digit])],
                    focusHouses: [box, link, crossed, kept],
                    patternCells: [x, y] + boxCells,
                    patternDigits: [digit]
                )
            }
        }
        return nil
    }
}
