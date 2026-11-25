//
//  Chains.swift
//  Sudoku
//

/// Alternating inference chains, shared by X-Chain, XY-Chain and AIC.
///
/// A chain is a sequence of candidates joined by links that alternate:
/// - **Strong link:** at least one of the two candidates is true. Either the same digit in the only
///   two cells of a house where it fits, or the two candidates of a cell that has exactly two.
/// - **Weak link:** at most one of the two is true. Either the same digit in two cells that see each
///   other, or two different digits in the same cell.
///
/// A chain that starts and ends with a strong link proves that at least one of its two ends is true:
/// if the first end is false, the strong link makes the next candidate true, the weak link after it
/// makes the next one false, and so on until the last end, which must be true. Anything that
/// contradicts both ends can be eliminated.
struct ChainSearch {
    enum Scope {
        /// One digit; strong links come from houses only (X-Chain).
        case singleDigit(Digit)
        /// Two-candidate cells only; strong links inside cells, weak links between cells (XY-Chain).
        case bivalueCells
        /// Every kind of link (AIC).
        case all
    }

    let board: Board
    let scope: Scope
    /// Longest chain considered, in links; longer chains are hard to follow.
    var maximumLinks = 13

    /// A chain found from one start, and what it eliminates.
    struct Result {
        let nodes: [ChainNode]
        let eliminations: [Elimination]
    }

    /// Every candidate a chain may use, in board order.
    var nodes: [ChainNode] {
        Geometry.cells.flatMap { cell in
            board.candidates(at: cell).compactMap { digit -> ChainNode? in
                let node = ChainNode(cell: cell, digit: digit)
                return allows(node) ? node : nil
            }
        }
    }

    /// The shortest useful chain over all starting candidates. Ties keep the first one found.
    /// `accept` can reject chains a technique doesn't want (e.g. XY-Chains whose ends differ).
    func shortestChain(accepting accept: (Result) -> Bool = { _ in true }) -> Result? {
        var best: Result?
        for start in nodes {
            guard let result = shortestChain(from: start, accepting: accept) else { continue }
            if best.map({ result.nodes.count < $0.nodes.count }) ?? true {
                best = result
                // Four candidates (strong, weak, strong) is the shortest possible chain.
                if result.nodes.count <= 4 { break }
            }
        }
        return best
    }

    /// Breadth-first search from `start`, alternating strong and weak links, for the shortest chain
    /// ending in a strong link that eliminates something.
    func shortestChain(from start: ChainNode, accepting accept: (Result) -> Bool = { _ in true }) -> Result? {
        // A state is a candidate together with the kind of link that reached it.
        struct State: Hashable {
            let node: ChainNode
            let arrivedByStrongLink: Bool
        }
        let first = State(node: start, arrivedByStrongLink: false)
        var parents: [State: State] = [:]
        var visited: Set<State> = [first]
        var frontier = [first]
        var links = 0

        while !frontier.isEmpty, links < maximumLinks {
            links += 1
            var next: [State] = []
            for state in frontier {
                // After a weak link (or at the start) comes a strong link, and the other way round.
                let takesStrongLink = !state.arrivedByStrongLink
                let neighbors = takesStrongLink ? strongLinks(from: state.node) : weakLinks(from: state.node)
                for neighbor in neighbors {
                    let child = State(node: neighbor, arrivedByStrongLink: takesStrongLink)
                    guard visited.insert(child).inserted else { continue }
                    parents[child] = state
                    let path = path(to: child, parents: parents)
                    // A candidate may appear only once in a chain.
                    guard Set(path.map(\.node)).count == path.count else { continue }
                    next.append(child)

                    if takesStrongLink, links >= 3 {
                        let nodes = path.map(\.node)
                        let eliminations = eliminations(between: start, and: neighbor)
                        let result = Result(nodes: nodes, eliminations: eliminations)
                        if !eliminations.isEmpty, accept(result) {
                            return result
                        }
                    }
                }
            }
            frontier = next
        }
        return nil
    }

    private func path<State: Hashable>(to state: State, parents: [State: State]) -> [State] {
        var path = [state]
        var current = state
        while let parent = parents[current] {
            path.insert(parent, at: 0)
            current = parent
        }
        return path
    }

    // MARK: Links

    private func allows(_ node: ChainNode) -> Bool {
        switch scope {
        case .singleDigit(let digit): node.digit == digit
        case .bivalueCells: board.candidates(at: node.cell).count == 2
        case .all: true
        }
    }

    func strongLinks(from node: ChainNode) -> [ChainNode] {
        var result: [ChainNode] = []
        if case .bivalueCells = scope {} else {
            for house in Geometry.houses(containing: node.cell) {
                let cells = board.cells(in: house, withCandidate: node.digit)
                if cells.count == 2, let partner = cells.first(where: { $0 != node.cell }) {
                    result.append(ChainNode(cell: partner, digit: node.digit))
                }
            }
        }
        if case .singleDigit = scope {} else {
            let digits = board.candidates(at: node.cell)
            if digits.count == 2, let other = digits.subtracting([node.digit]).single {
                result.append(ChainNode(cell: node.cell, digit: other))
            }
        }
        var seen = Set<ChainNode>()
        return result.filter { allows($0) && seen.insert($0).inserted }
    }

    func weakLinks(from node: ChainNode) -> [ChainNode] {
        var result = Geometry.peers[node.cell]
            .filter { board.candidates(at: $0).contains(node.digit) }
            .map { ChainNode(cell: $0, digit: node.digit) }
        if case .all = scope {
            for digit in board.candidates(at: node.cell) where digit != node.digit {
                result.append(ChainNode(cell: node.cell, digit: digit))
            }
        }
        return result.filter(allows)
    }

    // MARK: Eliminations

    /// What "at least one of `start` and `end` is true" rules out.
    func eliminations(between start: ChainNode, and end: ChainNode) -> [Elimination] {
        if start.cell == end.cell {
            // The cell is one of the two digits, so its other candidates go.
            let removed = board.candidates(at: start.cell).subtracting([start.digit, end.digit])
            return removed.isEmpty ? [] : [Elimination(cell: start.cell, digits: removed)]
        }
        if start.digit == end.digit {
            // One end holds the digit, so no cell seeing both can.
            return board.eliminations(of: start.digit, from: Geometry.cellsSeeingAll([start.cell, end.cell]))
        }
        guard Geometry.sees(start.cell, end.cell) else { return [] }
        // Different digits in cells that see each other: if the start is false the end is true and
        // rules out its digit in the start cell, and the other way round.
        var result: [Elimination] = []
        if board.candidates(at: start.cell).contains(end.digit) {
            result.append(Elimination(cell: start.cell, digits: [end.digit]))
        }
        if board.candidates(at: end.cell).contains(start.digit) {
            result.append(Elimination(cell: end.cell, digits: [start.digit]))
        }
        return result
    }
}

/// X-Chain: an alternating chain on one digit, built from strong links in houses.
struct XChain: Technique {
    let kind = TechniqueKind.xChain

    func findStep(in board: Board) -> SolveStep? {
        for digit in Geometry.digits {
            let search = ChainSearch(board: board, scope: .singleDigit(digit))
            if let result = search.shortestChain() {
                return step(for: result, technique: kind)
            }
        }
        return nil
    }
}

/// XY-Chain: a chain of two-candidate cells, each sharing a digit with the next, that starts and
/// ends on the same digit. Either the first cell or the last one holds it.
struct XYChain: Technique {
    let kind = TechniqueKind.xyChain

    func findStep(in board: Board) -> SolveStep? {
        let search = ChainSearch(board: board, scope: .bivalueCells)
        let result = search.shortestChain { result in
            // Ends on the same digit, in different cells.
            guard let first = result.nodes.first, let last = result.nodes.last else { return false }
            return first.digit == last.digit && first.cell != last.cell
        }
        return result.map { step(for: $0, technique: kind) }
    }
}

/// Alternating Inference Chain: strong and weak links of every kind, mixing digits and cells.
struct AIC: Technique {
    let kind = TechniqueKind.aic

    func findStep(in board: Board) -> SolveStep? {
        let search = ChainSearch(board: board, scope: .all)
        return search.shortestChain().map { step(for: $0, technique: kind) }
    }
}

private func step(for result: ChainSearch.Result, technique: TechniqueKind) -> SolveStep {
    var cells: [CellIndex] = []
    for node in result.nodes where !cells.contains(node.cell) {
        cells.append(node.cell)
    }
    return SolveStep(
        technique: technique,
        eliminations: result.eliminations,
        patternCells: cells,
        patternDigits: CandidateSet(result.nodes.map(\.digit)),
        chain: result.nodes
    )
}
