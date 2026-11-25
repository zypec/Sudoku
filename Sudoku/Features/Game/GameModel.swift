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
    private(set) var activeHint: ActiveHint? {
        didSet {
            if activeHint == nil {
                showsHintCandidates = false
            }
        }
    }
    private(set) var autoSolve: AutoSolveState?
    /// Whether the board shows every candidate around the active hint (detailed explanation).
    private(set) var showsHintCandidates = false
    /// Seconds played. Kept apart from `game` so the clock ticking every second doesn't redraw
    /// everything that reads the game, like the board; written into `game` whenever it's saved.
    private(set) var elapsedSeconds: Int
    /// The clock is stopped and the board hidden until the player resumes.
    private(set) var isPaused = false

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

    /// A hint being shown and the page the player is on. While the visual explanation is open,
    /// its frames replace the pages.
    struct ActiveHint: Equatable {
        let hint: Hint
        let pages: [HintPage]
        var pageIndex = 0
        var visualFrames: [HintPage]?
        var visualIndex = 0

        var isVisual: Bool {
            visualFrames != nil
        }

        /// What's on screen: a page, or a frame of the visual explanation.
        var page: HintPage {
            if let visualFrames {
                return visualFrames[visualIndex]
            }
            return pages[pageIndex]
        }

        var index: Int {
            isVisual ? visualIndex : pageIndex
        }

        var count: Int {
            visualFrames?.count ?? pages.count
        }

        var canGoBack: Bool {
            index > 0
        }

        var canGoForward: Bool {
            index < count - 1
        }
    }

    /// Records the game in the statistics when it finishes; `nil` in previews and most tests.
    @ObservationIgnored private let recorder: GameRecorder?
    /// A game is recorded once, when it finishes.
    @ObservationIgnored private var hasRecordedResult: Bool

    /// Whether the mistake-limit setting applies to this game (not in training).
    @ObservationIgnored private let followsMistakeLimitSetting: Bool

    init(game: SudokuGame, settings: AppSettings, store: GameStore? = nil, recorder: GameRecorder? = nil, followsMistakeLimitSetting: Bool = true) {
        self.game = game
        elapsedSeconds = game.elapsedSeconds
        self.settings = settings
        self.store = store
        self.recorder = recorder
        self.followsMistakeLimitSetting = followsMistakeLimitSetting
        hasRecordedResult = game.isFinished
        // A saved game picks up the limit set since it was started.
        if followsMistakeLimitSetting {
            self.game.setMistakeLimit(settings.mistakeLimitSetting)
        }
    }

    /// Applies the current mistake-limit setting to the game in progress.
    func applyMistakeLimitSetting() {
        guard followsMistakeLimitSetting, game.mistakeLimit != settings.mistakeLimitSetting else { return }
        update { $0.setMistakeLimit(settings.mistakeLimitSetting) }
    }

    /// Takes a puzzle from the bank (or generates one) and wraps it in a saved model. The mistake
    /// limit comes from the current settings and stays fixed for the whole game.
    static func make(difficulty: Difficulty, settings: AppSettings, store: GameStore? = nil, recorder: GameRecorder? = nil) async -> GameModel {
        let puzzle = await PuzzleSource.shared.puzzle(difficulty)
        let model = GameModel(
            game: SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitSetting),
            settings: settings,
            store: store,
            recorder: recorder
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
        syncClock()
        store?.save(game)
    }

    /// Copies the clock into the game before it's saved or recorded.
    private func syncClock() {
        if game.elapsedSeconds != elapsedSeconds {
            game.elapsedSeconds = elapsedSeconds
        }
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
        guard let activeHint else { return HintHighlights() }
        var highlights = activeHint.page.highlights
        if showsHintCandidates {
            let board = HintFinder.candidateBoard(for: game)
            for cell in hintCells {
                highlights.showCandidates(board.candidates(at: cell), in: cell)
            }
        }
        return highlights
    }

    /// Empty cells the active hint involves: its houses, pattern, chain and targets.
    var hintCells: [CellIndex] {
        guard let activeHint else { return [] }
        var cells = Set<CellIndex>()
        for step in activeHint.hint.steps {
            cells.formUnion(step.focusHouses.flatMap(\.cells))
            cells.formUnion(step.patternCells)
            cells.formUnion(step.chain.map(\.cell))
            cells.formUnion(step.eliminations.map(\.cell))
            cells.formUnion(step.placements.map(\.cell))
        }
        return cells.filter { game.values[$0] == 0 }.sorted()
    }

    func setShowsHintCandidates(_ shows: Bool) {
        showsHintCandidates = shows
    }

    /// Whether some cell around the hint has no notes yet, so its candidates could be added.
    var canAddHintCandidatesToNotes: Bool {
        hintCells.contains { game.notes[$0].isEmpty }
    }

    /// Writes the candidates of the hint's cells into those that have no notes yet.
    func addHintCandidatesToNotes() {
        let board = HintFinder.candidateBoard(for: game)
        let candidates = Dictionary(uniqueKeysWithValues: hintCells.map { ($0, board.candidates(at: $0)) })
        update { $0.fillEmptyNotes(with: candidates) }
    }

    /// Whether a hint or auto solve is drawing on the board (selection highlighting is hidden then).
    var isShowingHintHighlights: Bool {
        activeHint != nil || autoSolve != nil
    }

    func requestHint() {
        guard !game.isFinished else { return }
        let hint = HintFinder.hint(for: game)
        update { $0.registerHint(for: hint.mainTechnique) }
        activeHint = ActiveHint(hint: hint, pages: HintWalkthrough.pages(for: hint))
    }

    func showNextHintPage() {
        guard let activeHint, activeHint.canGoForward else { return }
        if activeHint.isVisual {
            self.activeHint?.visualIndex += 1
        } else {
            self.activeHint?.pageIndex += 1
        }
    }

    func showPreviousHintPage() {
        guard let activeHint, activeHint.canGoBack else { return }
        if activeHint.isVisual {
            self.activeHint?.visualIndex -= 1
        } else {
            self.activeHint?.pageIndex -= 1
        }
    }

    /// Plays the hint as a visual proof on the board (`VisualProof`).
    func startVisualExplanation() {
        guard let hint = activeHint?.hint, !hint.steps.isEmpty else { return }
        activeHint?.visualFrames = VisualProof.frames(for: hint)
        activeHint?.visualIndex = 0
    }

    func endVisualExplanation() {
        activeHint?.visualFrames = nil
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

    /// Fixes the note problem the active hint points out.
    func fixNotes() {
        switch activeHint?.hint {
        case .impossibleNotes(let eliminations, _)?:
            update { $0.removeNotes(eliminations) }
        case .notesMissingSolution(let cells)?:
            update { $0.refillNotes(in: cells) }
        default:
            return
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

    // MARK: Pause

    func pause() {
        guard !game.isFinished else { return }
        isPaused = true
        pauseAutoSolve()
        save()
    }

    func resume() {
        isPaused = false
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
        case .incorrectEntries(let cells)?, .notesMissingSolution(let cells)?:
            cells.first
        case .impossibleNotes(let eliminations, _)?:
            eliminations.first?.cell
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
        previous.elapsedSeconds = elapsedSeconds
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
            if let highlights = page?.highlights {
                switch hint {
                case .incorrectEntries:
                    page = HintPage(kind: .result, text: String(localized: "The incorrect digits will be erased."), highlights: highlights)
                case .impossibleNotes, .notesMissingSolution:
                    page = HintPage(kind: .result, text: String(localized: "The notes in the highlighted cells will be fixed."), highlights: highlights)
                default:
                    break
                }
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
                    $0.registerHint(for: step.technique)
                    $0.registerAutoSolvedStep()
                    $0.apply(step)
                }
            case .chain(let links):
                update {
                    $0.registerHint(for: hint.mainTechnique)
                    $0.registerAutoSolvedStep()
                    for link in links {
                        $0.apply(link.step)
                    }
                }
            case .incorrectEntries:
                update { $0.eraseIncorrectEntries() }
            case .impossibleNotes(let eliminations, _):
                update { $0.removeNotes(eliminations) }
            case .notesMissingSolution(let cells):
                update { $0.refillNotes(in: cells) }
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
        elapsedSeconds += 1
    }

    /// Replaces the current game with a fresh puzzle of the same difficulty, using the
    /// current mistake-limit setting.
    func startNewGame() async {
        isPreparingNewGame = true
        let puzzle = await PuzzleSource.shared.puzzle(game.puzzle.difficulty)
        game = SudokuGame(puzzle: puzzle, mistakeLimit: settings.mistakeLimitSetting)
        elapsedSeconds = 0
        hasRecordedResult = false
        isPaused = false
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
        save()  // also copies the clock in, before a finished game is recorded
        if game.isFinished, !hasRecordedResult {
            hasRecordedResult = true
            recorder?.record(game)
        }
    }

    /// Estimated share of players slower than this game's time, once it is solved.
    var shareOfSlowerPlayers: Double? {
        guard game.isSolved, !game.usedAutoSolve, let estimate = game.puzzle.estimatedSeconds else { return nil }
        return SolveTimeEstimate.shareOfSlowerPlayers(than: game.elapsedSeconds, estimate: estimate)
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
