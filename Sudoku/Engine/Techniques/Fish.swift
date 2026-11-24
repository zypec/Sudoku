//
//  Fish.swift
//  Sudoku
//

/// Basic fish: X-Wing (size 2). Swordfish (3) and Jellyfish (4) reuse this with a larger size.
///
/// Take `size` *base* lines (rows, say) in which a digit's candidates all fall into the same `size`
/// *cover* lines (columns). Each base line must hold the digit exactly once, and they can't share a
/// column, so the digit occupies every cover line inside the base lines. Therefore it can be removed
/// from the cover lines everywhere else. The same works with columns as base lines.
struct BasicFish: Technique {
    static let xWing = BasicFish(size: 2, kind: .xWing)

    let size: Int
    let kind: TechniqueKind

    private init(size: Int, kind: TechniqueKind) {
        self.size = size
        self.kind = kind
    }

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            for (baseKind, coverKind) in [(House.Kind.row, House.Kind.column), (.column, .row)] {
                if let step = findStep(for: digit, base: baseKind, cover: coverKind, in: board) {
                    return step
                }
            }
        }
        return nil
    }

    private func findStep(for digit: Digit, base baseKind: House.Kind, cover coverKind: House.Kind, in board: Board) -> SolveStep? {
        // Position of a cell across the base line, i.e. the index of the cover line it lies in.
        let coverIndex = { (cell: CellIndex) -> Int in
            coverKind == .column ? Geometry.column(of: cell) : Geometry.row(of: cell)
        }

        // Base lines where the digit is still open in 2...size cells. A line with a single cell is a
        // hidden single, and one with more cells can't fit `size` cover lines.
        let candidateLines = (0..<9).compactMap { index -> (House, [CellIndex])? in
            let line = House(kind: baseKind, index: index)
            let cells = board.cells(in: line, withCandidate: digit)
            return (2...size).contains(cells.count) ? (line, cells) : nil
        }

        for combination in candidateLines.combinations(ofSize: size) {
            let patternCells = combination.flatMap(\.1)
            let coverIndices = Set(patternCells.map(coverIndex)).sorted()
            guard coverIndices.count == size else { continue }

            let baseLines = combination.map(\.0)
            let coverLines = coverIndices.map { House(kind: coverKind, index: $0) }
            let targets = coverLines.flatMap(\.cells).filter { cell in
                !baseLines.contains { $0.contains(cell) }
            }
            let eliminations = board.eliminations(of: digit, from: targets)
            guard !eliminations.isEmpty else { continue }
            return SolveStep(
                technique: kind,
                eliminations: eliminations,
                focusHouses: baseLines + coverLines,
                patternCells: patternCells.sorted(),
                patternDigits: [digit]
            )
        }
        return nil
    }
}
