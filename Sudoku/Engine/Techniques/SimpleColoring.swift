//
//  SimpleColoring.swift
//  Sudoku
//

/// Simple Coloring (single-digit chains). Wherever a digit fits in exactly two cells of a house, one
/// of them holds it and the other doesn't. Chaining these strong links and coloring the cells
/// alternately splits a group of cells into two colors: one color holds the digit, the other doesn't.
///
/// - **Color wrap:** two cells of the same color see each other, so that color can't be the true one;
///   the digit is removed from every cell of it.
/// - **Color trap:** a cell outside the chain that sees both colors can't hold the digit.
///
/// `patternCells` is the chain in coloring order (its first cell has color A); the colors and links
/// can be rebuilt with `SimpleColoring.chain(of:startingAt:in:)`.
struct SimpleColoring: Technique {
    let kind = TechniqueKind.simpleColoring

    /// A colored group of cells linked by strong links on one digit.
    struct Chain: Equatable {
        /// Cells in coloring order, each with its color (`true` for color A).
        var cells: [(cell: CellIndex, isColorA: Bool)]
        /// Strong links, as pairs of cells, in the order they were followed.
        var links: [(CellIndex, CellIndex)]

        var colorA: [CellIndex] { cells.filter(\.isColorA).map(\.cell) }
        var colorB: [CellIndex] { cells.filter { !$0.isColorA }.map(\.cell) }

        static func == (lhs: Chain, rhs: Chain) -> Bool {
            lhs.cells.map(\.cell) == rhs.cells.map(\.cell) && lhs.cells.map(\.isColorA) == rhs.cells.map(\.isColorA)
        }
    }

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            var visited = Set<CellIndex>()
            for start in Geometry.cells where board.candidates(at: start).contains(digit) && !visited.contains(start) {
                let chain = Self.chain(of: digit, startingAt: start, in: board)
                visited.formUnion(chain.cells.map(\.cell))
                // Two cells are one strong link; anything it proves is found by simpler techniques.
                guard chain.cells.count >= 3 else { continue }
                if let step = step(for: chain, digit: digit, in: board) {
                    return step
                }
            }
        }
        return nil
    }

    private func step(for chain: Chain, digit: Digit, in board: Board) -> SolveStep? {
        let patternCells = chain.cells.map(\.cell)
        // Color wrap: a color that sees itself is false.
        for color in [chain.colorA, chain.colorB] {
            let seesItself = color.combinations(ofSize: 2).contains { Geometry.sees($0[0], $0[1]) }
            if seesItself {
                return SolveStep(
                    technique: kind,
                    eliminations: board.eliminations(of: digit, from: color),
                    patternCells: patternCells,
                    patternDigits: [digit]
                )
            }
        }
        // Color trap: outside cells that see both colors.
        let targets = Geometry.cells.filter { cell in
            !patternCells.contains(cell)
                && board.candidates(at: cell).contains(digit)
                && chain.colorA.contains { Geometry.sees(cell, $0) }
                && chain.colorB.contains { Geometry.sees(cell, $0) }
        }
        guard !targets.isEmpty else { return nil }
        return SolveStep(
            technique: kind,
            eliminations: board.eliminations(of: digit, from: targets),
            patternCells: patternCells,
            patternDigits: [digit]
        )
    }

    /// Colors every cell reachable from `start` through strong links on `digit` (breadth first).
    static func chain(of digit: Digit, startingAt start: CellIndex, in board: Board) -> Chain {
        var colors: [CellIndex: Bool] = [start: true]
        var order: [CellIndex] = [start]
        var links: [(CellIndex, CellIndex)] = []
        var queue = [start]
        while !queue.isEmpty {
            let cell = queue.removeFirst()
            for house in Geometry.houses(containing: cell) {
                let cells = board.cells(in: house, withCandidate: digit)
                guard cells.count == 2, let partner = cells.first(where: { $0 != cell }) else { continue }
                guard colors[partner] == nil else { continue }
                colors[partner] = !(colors[cell] ?? true)
                order.append(partner)
                links.append((cell, partner))
                queue.append(partner)
            }
        }
        return Chain(cells: order.map { ($0, colors[$0] ?? true) }, links: links)
    }
}
