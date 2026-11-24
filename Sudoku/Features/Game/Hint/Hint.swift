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

/// How much of a step hint is revealed. Each stage shows more than the previous one.
enum HintStage: Int, CaseIterable, Comparable, Sendable {
    /// The technique's name and the house to look at.
    case nudge
    /// The pattern and why it works.
    case explanation
    /// The resulting placement or eliminations, ready to apply.
    case result

    static func < (lhs: HintStage, rhs: HintStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var next: HintStage? {
        HintStage(rawValue: rawValue + 1)
    }
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

/// What the board should emphasize for a hint at a given stage.
struct HintHighlights: Equatable {
    /// How a single cell is drawn while a hint is shown.
    struct CellStyle: Equatable {
        var isFocus = false
        var isPattern = false
        var isIncorrect = false
        /// Candidates forming the pattern, drawn bold even if the player has no notes.
        var emphasizedNotes = CandidateSet()
        /// Candidates the step removes, drawn struck through.
        var eliminatedNotes = CandidateSet()
        /// Digit the step places, drawn as a preview.
        var ghostDigit: Digit?
    }

    private var styles: [CellIndex: CellStyle] = [:]

    init() {}

    init(hint: Hint, stage: HintStage) {
        switch hint {
        case .incorrectEntries(let cells):
            for cell in cells {
                styles[cell, default: CellStyle()].isIncorrect = true
            }

        case .unavailable:
            break

        case .step(let step, let board):
            // The nudge only points at the first house; later stages show every house involved.
            let houses = stage == .nudge ? Array(step.focusHouses.prefix(1)) : step.focusHouses
            for cell in houses.flatMap(\.cells) {
                styles[cell, default: CellStyle()].isFocus = true
            }
            // Wings have no house to point at; point at their pivot cell instead.
            if step.focusHouses.isEmpty, let pivot = step.patternCells.first {
                styles[pivot, default: CellStyle()].isFocus = true
            }
            guard stage >= .explanation else { return }

            for cell in step.patternCells {
                styles[cell, default: CellStyle()].isPattern = true
                // For eliminations, show the pattern's candidates. For placements this would give
                // the answer away before the result stage.
                if step.placements.isEmpty {
                    styles[cell, default: CellStyle()].emphasizedNotes = board.candidates(at: cell).intersection(step.patternDigits)
                }
            }
            guard stage == .result else { return }

            for placement in step.placements {
                styles[placement.cell, default: CellStyle()].ghostDigit = placement.digit
            }
            for elimination in step.eliminations {
                styles[elimination.cell, default: CellStyle()].eliminatedNotes = elimination.digits
            }
        }
    }

    func style(for cell: CellIndex) -> CellStyle? {
        styles[cell]
    }

    var isEmpty: Bool {
        styles.isEmpty
    }
}
