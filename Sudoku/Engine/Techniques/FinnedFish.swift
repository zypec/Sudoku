//
//  FinnedFish.swift
//  Sudoku
//

/// Finned X-Wing and Finned Swordfish.
///
/// Take `size` base lines whose candidates for a digit fall into `size` cover lines, except for a few
/// extra *fin* cells that all lie in one box. If no fin holds the digit, the basic fish works and the
/// digit leaves the cover lines outside the base lines. If a fin holds it, the digit leaves every cell
/// the fin sees. So the digit can be removed from cells that are in a cover line, outside the base
/// lines, and inside the fins' box: they lose it either way. (When a base line keeps only one corner,
/// this is also called a sashimi fish; the reasoning is the same.)
///
/// `focusHouses` are `[base lines…, cover lines…, fin box]`. `patternCells` are every base-line cell
/// with the digit; the fins are those outside the cover lines.
struct FinnedFish: Technique {
    static let xWing = FinnedFish(size: 2, kind: .finnedXWing)
    static let swordfish = FinnedFish(size: 3, kind: .finnedSwordfish)

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
        let coverIndex = { (cell: CellIndex) -> Int in
            coverKind == .column ? Geometry.column(of: cell) : Geometry.row(of: cell)
        }
        // A base line holds at most `size` corners plus the fins, which fit in one box (3 cells).
        let candidateLines = (0..<9).compactMap { index -> (House, [CellIndex])? in
            let line = House(kind: baseKind, index: index)
            let cells = board.cells(in: line, withCandidate: digit)
            return (2...(size + 3)).contains(cells.count) ? (line, cells) : nil
        }

        for combination in candidateLines.combinations(ofSize: size) {
            let cells = combination.flatMap(\.1)
            let crossIndices = Set(cells.map(coverIndex)).sorted()
            // With exactly `size` cover lines there is no fin: that's a basic fish.
            guard crossIndices.count > size else { continue }

            for covers in crossIndices.combinations(ofSize: size) {
                let fins = cells.filter { !covers.contains(coverIndex($0)) }
                guard let firstFin = fins.first else { continue }
                let finBox = Geometry.box(of: firstFin)
                guard fins.allSatisfy({ Geometry.box(of: $0) == finBox }),
                      // Every base line keeps at least one corner in the cover lines.
                      combination.allSatisfy({ line in line.1.contains { covers.contains(coverIndex($0)) } })
                else { continue }

                let baseLines = combination.map(\.0)
                let coverLines = covers.map { House(kind: coverKind, index: $0) }
                let box = House(kind: .box, index: finBox)
                let targets = coverLines.flatMap(\.cells).filter { cell in
                    box.contains(cell) && !baseLines.contains { $0.contains(cell) }
                }
                let eliminations = board.eliminations(of: digit, from: targets)
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    focusHouses: baseLines + coverLines + [box],
                    patternCells: cells.sorted(),
                    patternDigits: [digit]
                )
            }
        }
        return nil
    }
}
