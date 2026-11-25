//
//  Hint.swift
//  Sudoku
//

/// What the hint system has to say about the current position.
enum Hint: Equatable, Sendable {
    /// The board has wrong entries; logic can't continue until they are fixed.
    case incorrectEntries([CellIndex])
    /// The easiest next deduction, and the candidates it was found on.
    case step(SolveStep, board: Board)
    /// Eliminations the player can't act on (they aren't in their notes), followed by the placement
    /// they lead to. The last link holds the placement; every link keeps the board it was found on.
    case chain([ChainedStep])
    /// No known technique applies.
    case unavailable

    /// Every step the hint applies, in order.
    var steps: [SolveStep] {
        switch self {
        case .step(let step, _): [step]
        case .chain(let links): links.map(\.step)
        case .incorrectEntries, .unavailable: []
        }
    }

    /// The digit the hint ends up placing, if any.
    var placement: Placement? {
        steps.last?.placements.first
    }
}

/// One link of a chained hint: a step and the candidates it was found on.
struct ChainedStep: Equatable, Sendable {
    let step: SolveStep
    let board: Board
}

/// Finds the next logical step for the player's current position.
enum HintFinder {
    /// Longest run of eliminations followed to reach a placement.
    private static let chainLimit = 12

    /// - Parameter chainsEliminations: When the next step only removes candidates the player hasn't
    ///   noted, follow the logic on to the placement it leads to and return that as a `.chain`.
    ///   Auto solve turns this off to show every step on its own.
    static func hint(for game: SudokuGame, solver: LogicalSolver = LogicalSolver(), chainsEliminations: Bool = true) -> Hint {
        let incorrect = game.incorrectCells
        guard incorrect.isEmpty else { return .incorrectEntries(incorrect) }

        let board = candidateBoard(for: game)
        guard let step = solver.nextStep(on: board) else { return .unavailable }
        guard chainsEliminations, step.placements.isEmpty, !removesNotedCandidates(step, in: game) else {
            return .step(step, board: board)
        }

        // Follow eliminations until a placement appears. Every single available after an elimination
        // is one it enabled, because the solver always tries singles first.
        var links = [ChainedStep(step: step, board: board)]
        var current = board
        current.apply(step)
        while links.count <= chainLimit, let next = solver.nextStep(on: current) {
            if !next.placements.isEmpty {
                return .chain(pruned(links, leadingTo: ChainedStep(step: next, board: current)))
            }
            links.append(ChainedStep(step: next, board: current))
            current.apply(next)
        }
        return .step(step, board: board)
    }

    /// Whether the step removes at least one candidate that the player has written as a note, so the
    /// player can act on it directly.
    private static func removesNotedCandidates(_ step: SolveStep, in game: SudokuGame) -> Bool {
        step.eliminations.contains { !game.notes[$0.cell].intersection($0.digits).isEmpty }
    }

    /// Drops eliminations the placement doesn't depend on. Walking backwards from the placement, a
    /// step is kept when it removes a candidate that something later relies on: the cells and houses
    /// of a kept pattern, or the cells a single looks at. This over-approximates, so it may keep a
    /// step that isn't strictly needed but never drops one that is.
    private static func pruned(_ links: [ChainedStep], leadingTo placement: ChainedStep) -> [ChainedStep] {
        var needed = Set<Int>()  // cell * 10 + digit
        func require(_ cell: CellIndex, _ digits: CandidateSet) {
            for digit in digits {
                needed.insert(cell * 10 + digit)
            }
        }
        func requirePattern(of step: SolveStep) {
            // A pattern depends on every candidate of its own cells and on the pattern digits
            // elsewhere in its houses.
            for cell in step.patternCells {
                require(cell, .all)
            }
            for cell in step.focusHouses.flatMap(\.cells) {
                require(cell, step.patternDigits)
            }
        }
        requirePattern(of: placement.step)
        if let target = placement.step.placements.first {
            // A single also depends on the digit in every cell that shares a house with its target.
            for peer in Geometry.peers[target.cell] {
                require(peer, [target.digit])
            }
        }

        var kept: [ChainedStep] = []
        for link in links.reversed() {
            let isNeeded = link.step.eliminations.contains { elimination in
                elimination.digits.contains { needed.contains(elimination.cell * 10 + $0) }
            }
            guard isNeeded else { continue }
            kept.insert(link, at: 0)
            requirePattern(of: link.step)
        }
        return kept + [placement]
    }

    /// Candidates derived from the placed digits, minus eliminations proven by earlier hints.
    /// When the player's notes never exclude a correct digit, they are trusted as well, so the hint
    /// continues from the player's own progress instead of repeating deductions already made.
    static func candidateBoard(for game: SudokuGame) -> Board {
        var board = Board(values: game.values)
        let solution = game.puzzle.solution
        let notesAreConsistent = Geometry.cells.allSatisfy { cell in
            game.values[cell] != 0 || game.notes[cell].isEmpty || game.notes[cell].contains(solution[cell])
        }

        for cell in Geometry.cells where game.values[cell] == 0 {
            var removed = game.deducedEliminations[cell]
            if notesAreConsistent && !game.notes[cell].isEmpty {
                removed = removed.union(CandidateSet.all.subtracting(game.notes[cell]))
            }
            board.eliminate(removed, from: cell)
        }

        // Proven eliminations never remove the solution, but fall back to plain candidates
        // rather than reason from a broken position if that ever happens.
        return board.isContradictory ? Board(values: game.values) : board
    }
}
