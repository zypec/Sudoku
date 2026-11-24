//
//  LockedCandidates.swift
//  Sudoku
//

/// Locked Candidates type 1. When every candidate for a digit inside a box lies in one row (or
/// column), the digit must be placed in that line within the box — so it can be removed from the
/// rest of the line outside the box.
struct Pointing: Technique {
    let kind = TechniqueKind.pointing

    func findStep(in board: Board) -> SolveStep? {
        for box in Geometry.houses where box.kind == .box {
            for digit in Geometry.digits {
                let cells = box.cells.filter { board.candidates(at: $0).contains(digit) }
                guard cells.count >= 2, let line = sharedLine(of: cells) else { continue }

                let targets = line.cells.filter { !box.contains($0) && board.candidates(at: $0).contains(digit) }
                guard !targets.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: targets.map { Elimination(cell: $0, digits: [digit]) },
                    focusHouses: [box, line],
                    patternCells: cells,
                    patternDigits: [digit]
                )
            }
        }
        return nil
    }

    /// The row or column containing all `cells`, if there is one.
    private func sharedLine(of cells: [CellIndex]) -> House? {
        guard let first = cells.first else { return nil }
        let row = Geometry.row(of: first)
        if cells.allSatisfy({ Geometry.row(of: $0) == row }) {
            return House(kind: .row, index: row)
        }
        let column = Geometry.column(of: first)
        if cells.allSatisfy({ Geometry.column(of: $0) == column }) {
            return House(kind: .column, index: column)
        }
        return nil
    }
}

/// Locked Candidates type 2 (box/line reduction). When every candidate for a digit inside a row
/// (or column) lies in one box, the digit must be placed in that box within the line — so it can be
/// removed from the rest of the box.
struct Claiming: Technique {
    let kind = TechniqueKind.claiming

    func findStep(in board: Board) -> SolveStep? {
        for line in Geometry.houses where line.kind != .box {
            for digit in Geometry.digits {
                let cells = line.cells.filter { board.candidates(at: $0).contains(digit) }
                guard let first = cells.first, cells.count >= 2 else { continue }
                let boxIndex = Geometry.box(of: first)
                guard cells.allSatisfy({ Geometry.box(of: $0) == boxIndex }) else { continue }

                let box = House(kind: .box, index: boxIndex)
                let targets = box.cells.filter { !line.contains($0) && board.candidates(at: $0).contains(digit) }
                guard !targets.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: targets.map { Elimination(cell: $0, digits: [digit]) },
                    focusHouses: [line, box],
                    patternCells: cells,
                    patternDigits: [digit]
                )
            }
        }
        return nil
    }
}
