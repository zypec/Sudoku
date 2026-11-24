//
//  UniqueRectangle.swift
//  Sudoku
//

/// Unique Rectangle, types 1, 2 and 4. Relies on the puzzle having a single solution, which every
/// puzzle in this app does.
///
/// Four empty cells in two rows, two columns and exactly two boxes that could all hold the same two
/// digits {a, b} form a *deadly pattern*: if they ended up holding only a and b, the two digits could
/// be swapped and the puzzle would have two solutions. So the solution must break the pattern:
///
/// - **Type 1:** three corners are exactly {a, b}. The fourth corner can't be a or b.
/// - **Type 2:** two corners on one side (the *floor*) are exactly {a, b}; the other two (the *roof*)
///   are {a, b, x} with the same single extra x. One roof cell must be x, so any cell seeing both
///   roof cells can't be x.
/// - **Type 4:** floor as in type 2. If a is confined to the two roof cells within a house they share,
///   one roof cell is a, and the other can't be b (or the pattern would form), so b leaves both.
///
/// `patternCells`: type 1 `[corner, corner, corner, target]`; types 2 and 4 `[floor1, floor2, roof1,
/// roof2]`. `patternDigits` is {a, b}. Type 4's `focusHouses` is the house of the strong link.
struct UniqueRectangle: Technique {
    enum Variant {
        case type1, type2, type4
    }

    let variant: Variant

    var kind: TechniqueKind {
        switch variant {
        case .type1: .uniqueRectangleType1
        case .type2: .uniqueRectangleType2
        case .type4: .uniqueRectangleType4
        }
    }

    func findStep(in board: Board) -> SolveStep? {
        for rows in Array(0..<9).combinations(ofSize: 2) {
            for columns in Array(0..<9).combinations(ofSize: 2) {
                let corners = rows.flatMap { row in columns.map { Geometry.cell(row: row, column: $0) } }
                guard corners.allSatisfy({ board.value(at: $0) == 0 }),
                      Set(corners.map(Geometry.box(of:))).count == 2
                else { continue }

                let common = corners.reduce(CandidateSet.all) { $0.intersection(board.candidates(at: $1)) }
                for pair in Array(common).combinations(ofSize: 2) {
                    let digits = CandidateSet(pair)
                    if let step = findStep(corners: corners, digits: digits, in: board) {
                        return step
                    }
                }
            }
        }
        return nil
    }

    private func findStep(corners: [CellIndex], digits: CandidateSet, in board: Board) -> SolveStep? {
        let bivalue = corners.filter { board.candidates(at: $0) == digits }
        let others = corners.filter { !bivalue.contains($0) }

        switch variant {
        case .type1:
            guard bivalue.count == 3, let target = others.first else { return nil }
            let removed = board.candidates(at: target).intersection(digits)
            guard !removed.isEmpty else { return nil }
            return SolveStep(
                technique: kind,
                eliminations: [Elimination(cell: target, digits: removed)],
                patternCells: bivalue + [target],
                patternDigits: digits
            )

        case .type2:
            guard bivalue.count == 2, sharesLine(bivalue), others.count == 2 else { return nil }
            let extras = others.map { board.candidates(at: $0).subtracting(digits) }
            guard let x = extras[0].single, extras[1] == [x] else { return nil }
            let eliminations = board.eliminations(of: x, from: Geometry.cellsSeeingAll(others))
            guard !eliminations.isEmpty else { return nil }
            return SolveStep(
                technique: kind,
                eliminations: eliminations,
                patternCells: bivalue + others,
                patternDigits: digits
            )

        case .type4:
            guard bivalue.count == 2, sharesLine(bivalue), others.count == 2 else { return nil }
            let shared = Geometry.houses(containing: others[0]).filter { $0.contains(others[1]) }
            for house in shared {
                for strong in digits {
                    guard Set(board.cells(in: house, withCandidate: strong)) == Set(others) else { continue }
                    let weak = digits.subtracting([strong])
                    let eliminations = others.compactMap { cell -> Elimination? in
                        let removed = board.candidates(at: cell).intersection(weak)
                        return removed.isEmpty ? nil : Elimination(cell: cell, digits: removed)
                    }
                    guard !eliminations.isEmpty else { continue }
                    return SolveStep(
                        technique: kind,
                        eliminations: eliminations,
                        focusHouses: [house],
                        patternCells: bivalue + others,
                        patternDigits: digits
                    )
                }
            }
            return nil
        }
    }

    /// Whether two corners are on the same side of the rectangle (not diagonal).
    private func sharesLine(_ cells: [CellIndex]) -> Bool {
        cells.count == 2
            && (Geometry.row(of: cells[0]) == Geometry.row(of: cells[1]) || Geometry.column(of: cells[0]) == Geometry.column(of: cells[1]))
    }
}
