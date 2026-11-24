//
//  SudokuGame.swift
//  Sudoku
//

/// The state of one game: the player's entries, notes, mistakes and undo history.
///
/// A plain value type with no UI dependencies so it can be unit tested and persisted.
struct SudokuGame: Codable, Sendable {
    enum EntryResult: Equatable {
        /// Nothing changed (given cell, same digit, or game over).
        case ignored
        /// The correct digit was placed.
        case placed
        /// A wrong digit was placed and counted as a mistake.
        case mistake
    }

    let puzzle: Puzzle
    /// Mistakes allowed before the game is lost; `nil` means unlimited. Fixed when the game starts.
    let mistakeLimit: Int?

    /// Givens plus the player's entries, `0` for empty cells.
    private(set) var values: [Digit]
    /// Pencil marks of every cell; always empty for filled cells.
    private(set) var notes: [CandidateSet]
    private(set) var mistakeCount = 0
    var elapsedSeconds = 0
    private(set) var hintCount = 0
    private(set) var revealCount = 0
    /// Candidates proven impossible by applied hints. Kept separately from the player's notes so
    /// the hint system remembers them even for players who don't take notes.
    private(set) var deducedEliminations: [CandidateSet]

    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    /// Undo restores entries and notes but deliberately not the mistake count.
    private struct Snapshot: Codable, Sendable {
        var values: [Digit]
        var notes: [CandidateSet]
    }

    init(puzzle: Puzzle, mistakeLimit: Int?) {
        self.puzzle = puzzle
        self.mistakeLimit = mistakeLimit
        values = puzzle.givens
        notes = Array(repeating: .empty, count: Geometry.cellCount)
        deducedEliminations = Array(repeating: .empty, count: Geometry.cellCount)
    }

    // MARK: State

    func isGiven(_ cell: CellIndex) -> Bool {
        puzzle.givens[cell] != 0
    }

    /// Whether the player's entry in `cell` differs from the solution.
    func isIncorrect(_ cell: CellIndex) -> Bool {
        values[cell] != 0 && values[cell] != puzzle.solution[cell]
    }

    var isSolved: Bool {
        values == puzzle.solution
    }

    var isLost: Bool {
        guard let mistakeLimit else { return false }
        return mistakeCount >= mistakeLimit
    }

    var isFinished: Bool {
        isSolved || isLost
    }

    /// Cells holding a wrong entry.
    var incorrectCells: [CellIndex] {
        Geometry.cells.filter { isIncorrect($0) }
    }

    /// How many more times `digit` must be placed correctly.
    func remainingCount(of digit: Digit) -> Int {
        9 - Geometry.cells.count { values[$0] == digit && puzzle.solution[$0] == digit }
    }

    var canUndo: Bool { !isFinished && !undoStack.isEmpty }
    var canRedo: Bool { !isFinished && !redoStack.isEmpty }

    // MARK: Actions

    /// Places `digit` in `cell`. A correct digit is also removed from the notes of its peers when
    /// `removingNotesFromPeers` is set; a wrong one leaves the player's notes alone.
    @discardableResult
    mutating func enter(_ digit: Digit, at cell: CellIndex, removingNotesFromPeers: Bool = true) -> EntryResult {
        guard !isFinished, !isGiven(cell), values[cell] != digit else { return .ignored }
        recordUndo()
        values[cell] = digit
        notes[cell] = .empty

        guard digit == puzzle.solution[cell] else {
            mistakeCount += 1
            return .mistake
        }
        if removingNotesFromPeers {
            for peer in Geometry.peers[cell] {
                notes[peer].remove(digit)
            }
        }
        return .placed
    }

    /// Adds or removes a pencil mark in an empty cell. Returns whether anything changed.
    @discardableResult
    mutating func toggleNote(_ digit: Digit, at cell: CellIndex) -> Bool {
        guard !isFinished, values[cell] == 0 else { return false }
        recordUndo()
        if notes[cell].contains(digit) {
            notes[cell].remove(digit)
        } else {
            notes[cell].insert(digit)
        }
        return true
    }

    /// Clears the player's entry and notes in `cell`. Returns whether anything changed.
    @discardableResult
    mutating func erase(at cell: CellIndex) -> Bool {
        guard !isFinished, !isGiven(cell), values[cell] != 0 || !notes[cell].isEmpty else { return false }
        recordUndo()
        values[cell] = 0
        notes[cell] = .empty
        return true
    }

    /// Fills every empty cell's notes with the digits not yet placed among its peers.
    /// Returns whether anything changed.
    @discardableResult
    mutating func fillNotes() -> Bool {
        guard !isFinished else { return false }
        let board = Board(values: values)
        let filled = Geometry.cells.map { values[$0] == 0 ? board.candidates(at: $0) : .empty }
        guard filled != notes else { return false }
        recordUndo()
        notes = filled
        return true
    }

    // MARK: Hints

    mutating func registerHint() {
        hintCount += 1
    }

    /// Applies a logical step from the hint system: eliminations are remembered and removed from the
    /// player's notes, placements are entered.
    mutating func apply(_ step: SolveStep) {
        guard !isFinished else { return }
        if !step.eliminations.isEmpty {
            var updatedNotes = notes
            for elimination in step.eliminations {
                deducedEliminations[elimination.cell] = deducedEliminations[elimination.cell].union(elimination.digits)
                updatedNotes[elimination.cell] = updatedNotes[elimination.cell].subtracting(elimination.digits)
            }
            if updatedNotes != notes {
                recordUndo()
                notes = updatedNotes
            }
        }
        for placement in step.placements {
            enter(placement.digit, at: placement.cell)
        }
    }

    /// Writes the solution into `cell`. Not counted as a mistake. Returns whether anything changed.
    @discardableResult
    mutating func reveal(at cell: CellIndex) -> Bool {
        let digit = puzzle.solution[cell]
        guard !isFinished, !isGiven(cell), values[cell] != digit else { return false }
        recordUndo()
        values[cell] = digit
        notes[cell] = .empty
        for peer in Geometry.peers[cell] {
            notes[peer].remove(digit)
        }
        revealCount += 1
        return true
    }

    /// Clears every wrong entry. Returns whether anything changed.
    @discardableResult
    mutating func eraseIncorrectEntries() -> Bool {
        let cells = incorrectCells
        guard !isFinished, !cells.isEmpty else { return false }
        recordUndo()
        for cell in cells {
            values[cell] = 0
        }
        return true
    }

    // MARK: Undo

    mutating func undo() {
        guard canUndo, let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentSnapshot)
        restore(snapshot)
    }

    mutating func redo() {
        guard canRedo, let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentSnapshot)
        restore(snapshot)
    }

    // MARK: Private

    private var currentSnapshot: Snapshot {
        Snapshot(values: values, notes: notes)
    }

    /// Undo history is capped so saved games stay small.
    private static let undoLimit = 200

    private mutating func recordUndo() {
        undoStack.append(currentSnapshot)
        if undoStack.count > Self.undoLimit {
            undoStack.removeFirst(undoStack.count - Self.undoLimit)
        }
        redoStack.removeAll()
    }

    private mutating func restore(_ snapshot: Snapshot) {
        values = snapshot.values
        notes = snapshot.notes
    }
}
