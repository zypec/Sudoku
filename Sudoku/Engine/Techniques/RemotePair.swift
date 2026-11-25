//
//  RemotePair.swift
//  Sudoku
//

/// A chain of cells that all have exactly the same two candidates {a, b}, each seeing the next.
/// Neighbors can't hold the same digit, so the digits alternate along the chain. Two cells an odd
/// number of steps apart (at least three) therefore hold different digits, one a and one b, and any
/// cell that sees both of them can be neither a nor b.
///
/// `patternCells` is the chain in order, from one end to the other; `patternDigits` is {a, b}.
struct RemotePair: Technique {
    let kind = TechniqueKind.remotePair

    func findStep(in board: Board) -> SolveStep? {
        let bivalue = Geometry.cells.filter { board.candidates(at: $0).count == 2 }
        let pairs = Set(bivalue.map { board.candidates(at: $0) })

        var best: SolveStep?
        for digits in pairs.sorted(by: { $0.rawValue < $1.rawValue }) {
            let cells = bivalue.filter { board.candidates(at: $0) == digits }
            guard cells.count >= 4 else { continue }
            for start in cells {
                guard let step = shortestChain(from: start, through: cells, digits: digits, in: board) else { continue }
                if best.map({ step.patternCells.count < $0.patternCells.count }) ?? true {
                    best = step
                }
            }
        }
        return best
    }

    /// Breadth-first search for the nearest cell an odd number of steps (three or more) away whose
    /// shared peers lose a candidate.
    private func shortestChain(from start: CellIndex, through cells: [CellIndex], digits: CandidateSet, in board: Board) -> SolveStep? {
        var parents: [CellIndex: CellIndex] = [:]
        var distance: [CellIndex: Int] = [start: 0]
        var queue = [start]
        while !queue.isEmpty {
            let cell = queue.removeFirst()
            for next in cells where distance[next] == nil && Geometry.sees(cell, next) {
                distance[next] = (distance[cell] ?? 0) + 1
                parents[next] = cell
                queue.append(next)

                guard let steps = distance[next], steps >= 3, steps % 2 == 1 else { continue }
                var chain = [next]
                while let parent = parents[chain[0]] {
                    chain.insert(parent, at: 0)
                }
                let targets = Geometry.cellsSeeingAll([start, next]).filter { !chain.contains($0) }
                let eliminations = targets.compactMap { target -> Elimination? in
                    let removed = board.candidates(at: target).intersection(digits)
                    return removed.isEmpty ? nil : Elimination(cell: target, digits: removed)
                }
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: kind,
                    eliminations: eliminations,
                    patternCells: chain,
                    patternDigits: digits
                )
            }
        }
        return nil
    }
}
