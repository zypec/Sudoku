//
//  PracticeModel.swift
//  Sudoku
//

import Foundation
import Observation

/// Which practice positions the player has solved, per technique, kept in `UserDefaults`.
@MainActor
final class TrainingProgress {
    static let shared = TrainingProgress()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ technique: TechniqueKind) -> String {
        "training.solved.\(technique.rawValue)"
    }

    func solvedPositions(of technique: TechniqueKind) -> Set<Int> {
        Set(defaults.array(forKey: key(technique)) as? [Int] ?? [])
    }

    /// The position the player was last on, to resume there.
    func currentPosition(of technique: TechniqueKind) -> Int {
        defaults.integer(forKey: "training.current.\(technique.rawValue)")
    }

    func setCurrentPosition(_ index: Int, of technique: TechniqueKind) {
        defaults.set(index, forKey: "training.current.\(technique.rawValue)")
    }

    func markSolved(_ index: Int, of technique: TechniqueKind) {
        var solved = solvedPositions(of: technique)
        guard solved.insert(index).inserted else { return }
        defaults.set(solved.sorted(), forKey: key(technique))
    }
}

/// A practice position turned into a playable game, and the step the solver expects there (which
/// is exactly the technique being practiced). Singles are practiced without notes, as they're
/// found in a real game; every other technique starts with all candidates noted, since its
/// result is candidates to remove.
struct PracticeSetup {
    let game: SudokuGame
    let expected: SolveStep

    init?(position: TrainingPositions.Position, technique: TechniqueKind, transform: PuzzleTransform) {
        guard let board = position.board(transformedBy: transform),
              let solution = BruteForceSolver.solution(of: board.values),
              let expected = LogicalSolver().nextStep(on: board),
              expected.technique == technique
        else { return nil }
        let puzzle = Puzzle(givens: board.values, solution: solution, difficulty: Difficulty(rawValue: technique.level) ?? .easy)
        let notes = technique.level > 1 ? Geometry.cells.map(board.candidates(at:)) : Array(repeating: CandidateSet.empty, count: Geometry.cellCount)
        game = SudokuGame(puzzle: puzzle, mistakeLimit: nil, notes: notes)
        self.expected = expected
    }
}

/// Drives a practice session for one technique: loads positions one after another and checks
/// every move against the step the technique makes there.
@MainActor
@Observable
final class PracticeModel {
    enum Status: Equatable {
        /// `done` of `total` candidates removed so far (both 0 for a placement).
        case working(done: Int, total: Int)
        /// The last move isn't part of the technique.
        case wrongMove
        case solved
    }

    let technique: TechniqueKind
    private(set) var positionIndex = 0
    private(set) var game: GameModel
    private(set) var status: Status = .working(done: 0, total: 0)
    /// Changes whenever a new position is loaded, so the screen can start fresh.
    private(set) var loadID = 0

    @ObservationIgnored private let positions: [TrainingPositions.Position]
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let progress: TrainingProgress
    @ObservationIgnored private var expected: SolveStep
    @ObservationIgnored private var initialNotes: [CandidateSet]

    var positionCount: Int {
        positions.count
    }

    var solvedCount: Int {
        progress.solvedPositions(of: technique).count
    }

    var isPlacement: Bool {
        !expected.placements.isEmpty
    }

    /// `nil` when there is nothing to practice for this technique yet.
    init?(technique: TechniqueKind, settings: AppSettings, positions: TrainingPositions = .bundled, progress: TrainingProgress = .shared, transform: Bool = true) {
        let list = positions.positions(for: technique)
        // Resume where the player left off.
        let start = list.isEmpty ? 0 : progress.currentPosition(of: technique) % list.count
        guard let (index, setup) = Self.firstSetup(in: list, from: start, technique: technique, transform: transform) else { return nil }
        self.technique = technique
        self.positions = list
        self.settings = settings
        self.progress = progress
        positionIndex = index
        game = GameModel(game: setup.game, settings: settings, followsMistakeLimitSetting: false)
        expected = setup.expected
        initialNotes = setup.game.notes
        prepare()
    }

    /// Points hints at the step's cells and remembers the position.
    private func prepare() {
        let cells = isPlacement ? expected.placements.map(\.cell) : expected.eliminations.map(\.cell)
        game.practiceFocus = (technique, cells, isPlacement)
        progress.setCurrentPosition(positionIndex, of: technique)
        evaluate()
    }

    /// The first position from `start` on (wrapping around) that sets up correctly.
    private static func firstSetup(in positions: [TrainingPositions.Position], from start: Int, technique: TechniqueKind, transform: Bool) -> (Int, PracticeSetup)? {
        for offset in 0..<positions.count {
            let index = (start + offset) % positions.count
            var generator = SystemRandomNumberGenerator()
            let symmetry = transform ? PuzzleTransform.random(using: &generator) : .identity
            if let setup = PracticeSetup(position: positions[index], technique: technique, transform: symmetry) {
                return (index, setup)
            }
        }
        return nil
    }

    func nextPosition() {
        load(from: positionIndex + 1)
    }

    /// The same position again, in a new transform.
    func retry() {
        load(from: positionIndex)
    }

    private func load(from start: Int) {
        guard let (index, setup) = Self.firstSetup(in: positions, from: start, technique: technique, transform: true) else { return }
        positionIndex = index
        game = GameModel(game: setup.game, settings: settings, followsMistakeLimitSetting: false)
        expected = setup.expected
        initialNotes = setup.game.notes
        loadID += 1
        prepare()
    }

    /// Compares the board with the technique's step. Called after every change.
    func evaluate() {
        let current = game.game
        let givens = current.puzzle.givens
        let placements = Set(expected.placements.map { $0.cell * 10 + $0.digit })
        let removals = Set(expected.eliminations.flatMap { elimination in elimination.digits.map { elimination.cell * 10 + $0 } })

        // A placement technique is done once its digit is in.
        if !placements.isEmpty, expected.placements.allSatisfy({ current.values[$0.cell] == $0.digit }) {
            finish()
            return
        }
        // Any other digit, or a note the technique doesn't remove, is a wrong move.
        let wrongDigit = Geometry.cells.contains { cell in
            givens[cell] == 0 && current.values[cell] != 0 && !placements.contains(cell * 10 + current.values[cell])
        }
        let removed = Geometry.cells.flatMap { cell -> [Int] in
            guard current.values[cell] == 0 else { return [] }
            return initialNotes[cell].subtracting(current.notes[cell]).map { cell * 10 + $0 }
        }
        if wrongDigit || removed.contains(where: { !removals.contains($0) }) {
            status = .wrongMove
            return
        }
        if placements.isEmpty, !removals.isEmpty, removed.count == removals.count {
            finish()
            return
        }
        status = .working(done: removed.count, total: removals.count)
    }

    private func finish() {
        guard status != .solved else { return }
        status = .solved
        progress.markSolved(positionIndex, of: technique)
    }

    func undoWrongMove() {
        game.undo()
        evaluate()
    }
}
