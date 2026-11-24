//
//  XYWing.swift
//  Sudoku
//

/// A *pivot* cell with candidates {x, y} sees two *pincer* cells with {x, z} and {y, z}.
///
/// If the pivot is x, the first pincer must be z; if it's y, the second pincer must be z. Either way
/// one pincer holds z, so any cell that sees both pincers can't.
///
/// `patternCells` are ordered `[pivot, pincer1, pincer2]`, where pincer1 shares x and pincer2 shares
/// y with the pivot; the eliminated digit is z.
struct XYWing: Technique {
    let kind = TechniqueKind.xyWing

    func findStep(in board: Board) -> SolveStep? {
        for pivot in Geometry.cells where board.candidates(at: pivot).count == 2 {
            let pivotDigits = board.candidates(at: pivot)
            // Bivalue peers sharing exactly one digit with the pivot.
            let pincers = Geometry.peers[pivot].filter { cell in
                let digits = board.candidates(at: cell)
                return digits.count == 2 && digits.intersection(pivotDigits).count == 1
            }

            for pair in pincers.combinations(ofSize: 2) {
                let first = board.candidates(at: pair[0])
                let second = board.candidates(at: pair[1])
                // Each pincer shares a different pivot digit, and their other digits match.
                guard first.intersection(pivotDigits) != second.intersection(pivotDigits),
                      let z = first.subtracting(pivotDigits).single,
                      second.subtracting(pivotDigits) == [z]
                else { continue }

                let targets = Geometry.cellsSeeingAll(pair).filter { $0 != pivot }
                let eliminations = board.eliminations(of: z, from: targets)
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    patternCells: [pivot, pair[0], pair[1]],
                    patternDigits: pivotDigits.union([z])
                )
            }
        }
        return nil
    }
}
