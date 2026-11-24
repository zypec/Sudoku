//
//  GameModel.swift
//  Sudoku
//

import Observation

/// Drives the game screen: owns the game state plus UI-only state such as the selected cell.
/// Every change made by the player is saved immediately so the game survives the app closing.
@MainActor
@Observable
final class GameModel {
    private(set) var game: SudokuGame
    private(set) var selectedCell: CellIndex?
    private(set) var isNotesMode = false
    private(set) var isPreparingNewGame = false
    private(set) var activeHint: ActiveHint?

    @ObservationIgnored let settings: AppSettings
    /// `nil` keeps the game in memory only (previews, tests).
    @ObservationIgnored private let store: GameStore?

    /// A hint being shown and the page the player is on.
    struct ActiveHint: Equatable {
        let hint: Hint
        let pages: [HintPage]
        var pageIndex = 0

        var page: HintPage {
            pages[pageIndex]
        }

        var canGoBack: Bool {
            pageIndex > 0
        }

        var canGoForward: Bool {
            pageIndex < pages.count - 1
        }
    }

    init(game: SudokuGame, settings: AppSettings, store: GameStore? = nil) {
        self.game = game
        self.settings = settings
        self.store = store
    }

    /// Generates a new puzzle in the background and wraps it in a saved model. The mistake limit
    /// comes from the current settings and stays fixed for the whole game.
    static func make(difficulty: Difficulty, settings: AppSettings, store: GameStore? = nil) async -> GameModel {
        let puzzle = await PuzzleGenerator.generate(difficulty)
        let model = GameModel(
            game: SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitForNewGame),
            settings: settings,
            store: store
        )
        model.save()
        return model
    }

    /// The digit in the selected cell, used to highlight the same digit elsewhere.
    var selectedDigit: Digit? {
        guard let selectedCell, game.values[selectedCell] != 0 else { return nil }
        return game.values[selectedCell]
    }

    /// Writes the game to disk (or clears the save once it's finished).
    func save() {
        store?.save(game)
    }

    // MARK: Input

    func select(_ cell: CellIndex) {
        selectedCell = cell
    }

    /// Handles a number pad tap: a pencil mark in notes mode, otherwise an entry.
    func input(_ digit: Digit) {
        guard let selectedCell else { return }
        if isNotesMode {
            update { $0.toggleNote(digit, at: selectedCell) }
        } else {
            let removesNotes = settings.removesNotesAutomatically
            update { $0.enter(digit, at: selectedCell, removingNotesFromPeers: removesNotes) }
        }
    }

    func eraseSelectedCell() {
        guard let selectedCell else { return }
        update { $0.erase(at: selectedCell) }
    }

    func toggleNotesMode() {
        isNotesMode.toggle()
    }

    func fillNotes() {
        update { $0.fillNotes() }
    }

    func undo() {
        update { $0.undo() }
    }

    func redo() {
        update { $0.redo() }
    }

    // MARK: Hints

    var hintHighlights: HintHighlights {
        activeHint?.page.highlights ?? HintHighlights()
    }

    func requestHint() {
        guard !game.isFinished else { return }
        update { $0.registerHint() }
        let hint = HintFinder.hint(for: game)
        activeHint = ActiveHint(hint: hint, pages: HintWalkthrough.pages(for: hint))
    }

    func showNextHintPage() {
        guard let activeHint, activeHint.canGoForward else { return }
        self.activeHint?.pageIndex += 1
    }

    func showPreviousHintPage() {
        guard let activeHint, activeHint.canGoBack else { return }
        self.activeHint?.pageIndex -= 1
    }

    func applyHint() {
        guard case .step(let step, _)? = activeHint?.hint else { return }
        update { $0.apply(step) }
        if let placement = step.placements.first {
            selectedCell = placement.cell
        }
        activeHint = nil
    }

    func eraseMistakes() {
        update { $0.eraseIncorrectEntries() }
        activeHint = nil
    }

    func closeHint() {
        activeHint = nil
    }

    /// The cell "Reveal Cell" would fill: the selected cell if it isn't already correct,
    /// otherwise the cell the current hint places a digit in.
    var revealTarget: CellIndex? {
        if let selectedCell, !game.isGiven(selectedCell), game.values[selectedCell] != game.puzzle.solution[selectedCell] {
            return selectedCell
        }
        if case .step(let step, _)? = activeHint?.hint {
            return step.placements.first?.cell
        }
        return nil
    }

    func revealCell() {
        guard let cell = revealTarget else { return }
        update { $0.reveal(at: cell) }
        selectedCell = cell
        activeHint = nil
    }

    // MARK: Lifecycle

    /// Advances the clock by one second while the game is running. Not saved on every tick;
    /// the view saves when the app leaves the foreground or the screen closes.
    func tick() {
        guard !game.isFinished else { return }
        game.elapsedSeconds += 1
    }

    /// Replaces the current game with a fresh puzzle of the same difficulty, using the
    /// current mistake-limit setting.
    func startNewGame() async {
        isPreparingNewGame = true
        let puzzle = await PuzzleGenerator.generate(game.puzzle.difficulty)
        game = SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitForNewGame)
        selectedCell = nil
        isNotesMode = false
        activeHint = nil
        isPreparingNewGame = false
        save()
    }

    /// Applies a change to the game and saves it.
    private func update(_ change: (inout SudokuGame) -> some Any) {
        _ = change(&game)
        save()
    }
}

extension GameModel: Hashable {
    nonisolated static func == (lhs: GameModel, rhs: GameModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
