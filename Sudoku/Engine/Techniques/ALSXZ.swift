//
//  ALSXZ.swift
//  Sudoku
//

/// ALS-XZ. An *almost locked set* (ALS) is a group of N empty cells in one house that together have
/// exactly N + 1 candidates: one digit more than they can hold. Remove any one of its digits and the
/// rest are locked in (they must all appear in the group).
///
/// Take two ALSs, A and B, that share a *restricted common* digit X: every X in A sees every X in B,
/// so X is in at most one of them. The group without X is then locked, so it contains every other
/// digit it has. If both groups also have a digit Z, at least one group holds Z, and any cell that
/// sees every Z in both groups can't be Z.
///
/// `cellGroups` is `[A, B]`, `patternCells` is A followed by B, `patternDigits` is {X, Z} and
/// `focusHouses` is the house of each group.
struct ALSXZ: Technique {
    let kind = TechniqueKind.alsXZ

    /// Largest group considered; bigger sets are rare and hard to follow.
    private let maximumSize = 3

    private struct AlmostLockedSet {
        let house: House
        let cells: [CellIndex]
        let digits: CandidateSet
    }

    func findStep(in board: Board) -> SolveStep? {
        let sets = almostLockedSets(in: board)
        for (index, a) in sets.enumerated() {
            for b in sets[(index + 1)...] where Set(a.cells).isDisjoint(with: b.cells) {
                let common = a.digits.intersection(b.digits)
                guard common.count >= 2 else { continue }
                for x in common where isRestricted(x, a, b, in: board) {
                    for z in common where z != x {
                        let zCells = (a.cells + b.cells).filter { board.candidates(at: $0).contains(z) }
                        let targets = Geometry.cells.filter { cell in
                            !a.cells.contains(cell) && !b.cells.contains(cell)
                                && zCells.allSatisfy { Geometry.sees(cell, $0) }
                        }
                        let eliminations = board.eliminations(of: z, from: targets)
                        guard !eliminations.isEmpty else { continue }
                        return SolveStep(
                            technique: kind,
                            eliminations: eliminations,
                            focusHouses: [a.house, b.house],
                            patternCells: a.cells + b.cells,
                            patternDigits: [x, z],
                            cellGroups: [a.cells, b.cells]
                        )
                    }
                }
            }
        }
        return nil
    }

    /// Every X of one group sees every X of the other.
    private func isRestricted(_ x: Digit, _ a: AlmostLockedSet, _ b: AlmostLockedSet, in board: Board) -> Bool {
        let xA = a.cells.filter { board.candidates(at: $0).contains(x) }
        let xB = b.cells.filter { board.candidates(at: $0).contains(x) }
        return xA.allSatisfy { cell in xB.allSatisfy { Geometry.sees(cell, $0) } }
    }

    /// Every ALS of up to `maximumSize` cells, each listed once even if it lies in two houses.
    private func almostLockedSets(in board: Board) -> [AlmostLockedSet] {
        var result: [AlmostLockedSet] = []
        var seen = Set<[CellIndex]>()
        for house in Geometry.houses {
            let empty = house.cells.filter { board.value(at: $0) == 0 }
            for size in 1...maximumSize where size < empty.count {
                for cells in empty.combinations(ofSize: size) {
                    let digits = cells.reduce(CandidateSet()) { $0.union(board.candidates(at: $1)) }
                    guard digits.count == size + 1, seen.insert(cells.sorted()).inserted else { continue }
                    result.append(AlmostLockedSet(house: house, cells: cells, digits: digits))
                }
            }
        }
        return result
    }
}
