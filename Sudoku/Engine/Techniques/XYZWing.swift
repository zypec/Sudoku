//
//  XYZWing.swift
//  Sudoku
//

/// A *pivot* cell with candidates {x, y, z} sees two *pincer* cells with {x, z} and {y, z}.
///
/// If the pivot is x, the first pincer is z; if it's y, the second pincer is z; otherwise the pivot
/// itself is z. So one of the three cells holds z, and any cell that sees all three can't.
///
/// `patternCells` are ordered `[pivot, pincer1, pincer2]`; the eliminated digit is z.
struct XYZWing: Technique {
    let kind = TechniqueKind.xyzWing

    func findStep(in board: Board) -> SolveStep? {
        for pivot in Geometry.cells where board.candidates(at: pivot).count == 3 {
            let pivotDigits = board.candidates(at: pivot)
            // Bivalue peers whose two digits both belong to the pivot.
            let pincers = Geometry.peers[pivot].filter { cell in
                let digits = board.candidates(at: cell)
                return digits.count == 2 && pivotDigits.isSuperset(of: digits)
            }

            for pair in pincers.combinations(ofSize: 2) {
                let first = board.candidates(at: pair[0])
                let second = board.candidates(at: pair[1])
                // Together the pincers cover the pivot, and they share exactly one digit: z.
                guard first.union(second) == pivotDigits, let z = first.intersection(second).single else { continue }

                let eliminations = board.eliminations(of: z, from: Geometry.cellsSeeingAll([pivot, pair[0], pair[1]]))
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    patternCells: [pivot, pair[0], pair[1]],
                    patternDigits: pivotDigits
                )
            }
        }
        return nil
    }
}
