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
    private(set) var autoSolve: AutoSolveState?

    @ObservationIgnored let settings: AppSettings
    /// `nil` keeps the game in memory only (previews, tests).
    @ObservationIgnored private let store: GameStore?
    @ObservationIgnored private var autoSolveTask: Task<Void, Never>?
    /// Set by "Next Step" to apply the step on screen without waiting.
    @ObservationIgnored private var skipsAutoSolveWait = false
    /// Set by "Previous Step" so the loop drops the step on screen and looks again.
    @ObservationIgnored private var refreshesAutoSolveStep = false
    /// The game before each applied auto solve step, so steps can be taken back exactly (including
    /// eliminations remembered by the hint system, which the regular undo doesn't track).
    @ObservationIgnored private var autoSolveHistory: [SudokuGame] = []

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
        if let page = autoSolve?.page {
            return page.highlights
        }
        return activeHint?.page.highlights ?? HintHighlights()
    }

    /// Whether a hint or auto solve is drawing on the board (selection highlighting is hidden then).
    var isShowingHintHighlights: Bool {
        activeHint != nil || autoSolve != nil
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
        guard let hint = activeHint?.hint, !hint.steps.isEmpty else { return }
        update { game in
            for step in hint.steps {
                game.apply(step)
            }
        }
        if let placement = hint.placement {
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
        if let placement = activeHint?.hint.placement {
            return placement.cell
        }
        return nil
    }

    func revealCell() {
        guard let cell = revealTarget else { return }
        update { $0.reveal(at: cell) }
        selectedCell = cell
        activeHint = nil
    }

    // MARK: Auto solve

    /// Solves the rest of the puzzle step by step: each step is shown on the board for a moment
    /// (see `AutoSolveSpeed`) and then applied. Every step counts as a hint and can be undone.
    func startAutoSolve() {
        guard !game.isFinished, autoSolve == nil else { return }
        activeHint = nil
        isNotesMode = false
        autoSolveHistory = []
        autoSolve = AutoSolveState()
        autoSolveTask = Task { await runAutoSolve() }
    }

    func stopAutoSolve() {
        autoSolveTask?.cancel()
        autoSolveTask = nil
        autoSolve = nil
        autoSolveHistory = []
    }

    /// The cell the step on screen is about: where a digit goes, or the first cell losing candidates.
    var autoSolveTarget: CellIndex? {
        switch autoSolve?.hint {
        case .step(let step, _)?:
            step.placements.first?.cell ?? step.eliminations.first?.cell
        case .chain?:
            autoSolve?.hint?.placement?.cell
        case .incorrectEntries(let cells)?:
            cells.first
        default:
            nil
        }
    }

    var canStepAutoSolveBack: Bool {
        autoSolve != nil && !autoSolveHistory.isEmpty
    }

    /// Takes back the last applied step and pauses, showing that step again.
    func autoSolvePreviousStep() {
        guard autoSolve != nil, var previous = autoSolveHistory.popLast() else { return }
        previous.elapsedSeconds = game.elapsedSeconds
        game = previous
        save()
        if var state = autoSolve {
            state.isPaused = true
            state.isStuck = false
            state.appliedSteps = max(0, state.appliedSteps - 1)
            autoSolve = state
        }
        refreshesAutoSolveStep = true
        // The loop ends when it gets stuck; start it again so it shows the restored step.
        if autoSolveTask == nil {
            autoSolveTask = Task { await runAutoSolve() }
        }
    }

    func toggleAutoSolvePause() {
        guard let autoSolve, !autoSolve.isStuck else { return }
        self.autoSolve?.isPaused.toggle()
    }

    func pauseAutoSolve() {
        autoSolve?.isPaused = true
    }

    /// Applies the step on screen right away; useful while paused to go one step at a time.
    func autoSolveNextStep() {
        guard autoSolve?.isStuck == false else { return }
        skipsAutoSolveWait = true
    }

    private func runAutoSolve() async {
        defer {
            if !Task.isCancelled {
                autoSolveTask = nil
            }
        }
        while !Task.isCancelled, autoSolve != nil, !game.isFinished {
            // Auto solve shows every step on its own, eliminations included.
            let hint = HintFinder.hint(for: game, chainsEliminations: false)
            var page = HintWalkthrough.pages(for: hint).last
            if case .incorrectEntries = hint, let highlights = page?.highlights {
                page = HintPage(kind: .result, text: String(localized: "The incorrect digits will be erased."), highlights: highlights)
            }
            autoSolve?.hint = hint
            autoSolve?.page = page

            if case .unavailable = hint {
                autoSolve?.isStuck = true
                autoSolve?.isPaused = true
                return
            }
            switch await waitForAutoSolveStep() {
            case .stop: return
            case .refresh: continue
            case .apply: break
            }

            autoSolveHistory.append(game)
            if autoSolveHistory.count > Self.autoSolveHistoryLimit {
                autoSolveHistory.removeFirst()
            }
            switch hint {
            case .step(let step, _):
                update {
                    $0.registerHint()
                    $0.apply(step)
                }
            case .chain(let links):
                update {
                    $0.registerHint()
                    for link in links {
                        $0.apply(link.step)
                    }
                }
            case .incorrectEntries:
                update { $0.eraseIncorrectEntries() }
            case .unavailable:
                break
            }
            autoSolve?.appliedSteps += 1
        }
        if game.isFinished {
            autoSolve = nil
            autoSolveTask = nil
        }
    }

    private static let autoSolveHistoryLimit = 300

    private enum AutoSolveWait {
        case apply, refresh, stop
    }

    /// Waits until the step on screen has been shown long enough. Only unpaused time counts, and the
    /// speed is read on every tick, so pausing or changing speed takes effect mid-step.
    private func waitForAutoSolveStep() async -> AutoSolveWait {
        let tick = 0.05
        var progress = 0.0
        skipsAutoSolveWait = false
        refreshesAutoSolveStep = false
        while progress < 1 {
            guard !Task.isCancelled, let state = autoSolve else { return .stop }
            if refreshesAutoSolveStep {
                refreshesAutoSolveStep = false
                return .refresh
            }
            if skipsAutoSolveWait {
                skipsAutoSolveWait = false
                return .apply
            }
            try? await Task.sleep(for: .seconds(tick))
            if !state.isPaused {
                progress += tick / settings.autoSolveSpeed.stepDuration
            }
        }
        return !Task.isCancelled && autoSolve != nil ? .apply : .stop
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
        stopAutoSolve()
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
