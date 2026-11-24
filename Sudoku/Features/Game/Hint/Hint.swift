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
    /// No known technique applies.
    case unavailable
}

/// Finds the next logical step for the player's current position.
enum HintFinder {
    static func hint(for game: SudokuGame, solver: LogicalSolver = LogicalSolver()) -> Hint {
        let incorrect = game.incorrectCells
        guard incorrect.isEmpty else { return .incorrectEntries(incorrect) }

        let board = candidateBoard(for: game)
        guard let step = solver.nextStep(on: board) else { return .unavailable }
        return .step(step, board: board)
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
