//
//  Skyscraper.swift
//  Sudoku
//

/// Two parallel lines (rows, say) in which a digit fits in exactly two cells each. One end of each
/// pair lies in the same column (the *base*), the other two ends (the *tops*) don't.
///
/// The two base cells see each other, so at most one of them holds the digit. If a base cell doesn't
/// hold it, the top in the same line must. So at least one top holds the digit, and any cell that sees
/// both tops can't. (If the tops shared a column too, this would be an X-Wing.)
///
/// `patternCells` are ordered `[top1, top2, base1, base2]`; `focusHouses` are `[line1, line2, baseLine]`.
struct Skyscraper: Technique {
    let kind = TechniqueKind.skyscraper

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            for (lineKind, crossKind) in [(House.Kind.row, House.Kind.column), (.column, .row)] {
                if let step = findStep(for: digit, lines: lineKind, cross: crossKind, in: board) {
                    return step
                }
            }
        }
        return nil
    }

    private func findStep(for digit: Digit, lines lineKind: House.Kind, cross crossKind: House.Kind, in board: Board) -> SolveStep? {
        let crossIndex = { (cell: CellIndex) -> Int in
            crossKind == .column ? Geometry.column(of: cell) : Geometry.row(of: cell)
        }
        let links = (0..<9).compactMap { index -> (House, [CellIndex])? in
            let line = House(kind: lineKind, index: index)
            let cells = board.cells(in: line, withCandidate: digit)
            return cells.count == 2 ? (line, cells) : nil
        }

        for pair in links.combinations(ofSize: 2) {
            let (line1, cells1) = pair[0]
            let (line2, cells2) = pair[1]
            // Try each end of the first pair as a base, matched with an end of the second pair.
            for (base1, top1) in [(cells1[0], cells1[1]), (cells1[1], cells1[0])] {
                for (base2, top2) in [(cells2[0], cells2[1]), (cells2[1], cells2[0])] {
                    guard crossIndex(base1) == crossIndex(base2), crossIndex(top1) != crossIndex(top2) else { continue }

                    let eliminations = board.eliminations(of: digit, from: Geometry.cellsSeeingAll([top1, top2]))
                    guard !eliminations.isEmpty else { continue }
                    return SolveStep(
                        technique: kind,
                        eliminations: eliminations,
                        focusHouses: [line1, line2, House(kind: crossKind, index: crossIndex(base1))],
                        patternCells: [top1, top2, base1, base2],
                        patternDigits: [digit]
                    )
                }
            }
        }
        return nil
    }
}
