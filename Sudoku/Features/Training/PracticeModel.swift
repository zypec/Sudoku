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

    // MARK: Random practice

    /// Random practice positions solved, per day (`yyyy-MM-dd` in the player's calendar).
    private var solvedPerDay: [String: Int] {
        defaults.dictionary(forKey: "training.random.perDay") as? [String: Int] ?? [:]
    }

    private static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func recordRandomSolved(on date: Date = .now, calendar: Calendar = .current) {
        var counts = solvedPerDay
        counts[Self.day(date, calendar: calendar), default: 0] += 1
        defaults.set(counts, forKey: "training.random.perDay")
    }

    func randomSolved(on date: Date = .now, calendar: Calendar = .current) -> Int {
        solvedPerDay[Self.day(date, calendar: calendar)] ?? 0
    }

    /// Random positions solved per day, from the first day one was solved through today; `nil` before
    /// the first.
    func randomDailyAverage(today: Date = .now, calendar: Calendar = .current) -> Double? {
        let counts = solvedPerDay
        guard let first = counts.keys.min() else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: first) else { return nil }
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? 0) + 1
        return Double(counts.values.reduce(0, +)) / Double(max(days, 1))
    }
}

/// One practice position as it is shown: the technique, its position in the training file and the
/// seed of the transform it is shown in. Its code names it, so a position can be shared.
struct PracticePick: Hashable, Sendable {
    let technique: TechniqueKind
    let index: Int
    let seed: UInt32

    /// `T` and eight characters of Crockford's base 32, like puzzle codes (`PuzzleCode`): the
    /// technique, the position and six for the seed, written `TXX-XXX-XXX`.
    var code: String {
        guard let kind = TechniqueKind.allCases.firstIndex(of: technique), kind < 32, index < 32 else { return "" }
        var digits = [kind, index]
        for shift in stride(from: 25, through: 0, by: -5) {
            digits.append(Int((seed >> UInt32(shift)) & 31))
        }
        let text = "T" + String(digits.map { Self.alphabet[$0] })
        return "\(text.prefix(3))-\(text.dropFirst(3).prefix(3))-\(text.suffix(3))"
    }

    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    init(technique: TechniqueKind, index: Int, seed: UInt32) {
        self.technique = technique
        self.index = index
        self.seed = seed
    }

    /// The pick a code stands for; spaces, dashes, letter case, and an O or I for 0 or 1 are forgiven.
    init?(code: String) {
        var values: [Int] = []
        for character in code.uppercased() where !character.isWhitespace && character != "-" {
            let read: Character = switch character {
            case "O": "0"
            case "I", "L": "1"
            default: character
            }
            values.append(Self.alphabet.firstIndex(of: read) ?? -1)
        }
        // The leading T is read as a letter of the alphabet, 26.
        guard values.count == 9, values[0] == 26, !values.contains(-1), values[1] < TechniqueKind.allCases.count else { return nil }
        technique = TechniqueKind.allCases[values[1]]
        index = values[2]
        seed = values[3...].reduce(UInt32(0)) { $0 << 5 | UInt32($1) }
    }

    static func random(technique: TechniqueKind, index: Int) -> PracticePick {
        PracticePick(technique: technique, index: index, seed: UInt32.random(in: 0..<PuzzleCode.seedLimit))
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

/// Drives a practice session: loads positions one after another and checks every move against
/// the step the technique makes there.
///
/// Practicing one technique, every move must be part of its step. Random practice gives a position
/// of any technique without naming it, and other right moves are possible there: a move that agrees
/// with the solution but isn't the expected step is offered to keep, going on to the expected step,
/// or to move on.
@MainActor
@Observable
final class PracticeModel {
    enum Status: Equatable {
        /// `done` of `total` candidates removed so far (both 0 for a placement).
        case working(done: Int, total: Int)
        /// The last move isn't part of the technique.
        case wrongMove
        /// Random practice: a right move, but not the expected step.
        case otherSolution
        case solved
    }

    /// Random practice, or one technique.
    let isRandom: Bool
    private(set) var pick: PracticePick
    private(set) var game: GameModel
    private(set) var status: Status = .working(done: 0, total: 0)
    /// Changes whenever a new position is loaded, so the screen can start fresh.
    private(set) var loadID = 0

    @ObservationIgnored private let positions: TrainingPositions
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let progress: TrainingProgress
    @ObservationIgnored private var expected: SolveStep
    @ObservationIgnored private var initialNotes: [CandidateSet]
    /// Other right moves the player chose to keep, as `cell * 10 + digit`.
    @ObservationIgnored private var keptMoves = Set<Int>()

    var technique: TechniqueKind {
        pick.technique
    }

    var positionIndex: Int {
        pick.index
    }

    var positionCount: Int {
        positions.positions(for: technique).count
    }

    var solvedCount: Int {
        progress.solvedPositions(of: technique).count
    }

    var isPlacement: Bool {
        !expected.placements.isEmpty
    }

    /// One technique, from where the player left off. `nil` when it has nothing to practice yet.
    convenience init?(technique: TechniqueKind, settings: AppSettings, positions: TrainingPositions = .bundled, progress: TrainingProgress = .shared, transform: Bool = true) {
        let count = positions.positions(for: technique).count
        guard count > 0 else { return nil }
        let start = progress.currentPosition(of: technique) % count
        self.init(isRandom: false, from: start, of: technique, settings: settings, positions: positions, progress: progress, transform: transform)
    }

    /// A position of any technique, chosen at random.
    convenience init?(randomWith settings: AppSettings, positions: TrainingPositions = .bundled, progress: TrainingProgress = .shared) {
        guard let pick = Self.randomPick(in: positions) else { return nil }
        self.init(isRandom: true, from: pick.index, of: pick.technique, settings: settings, positions: positions, progress: progress, transform: true, seed: pick.seed)
    }

    /// The position a training code names; practiced like random practice, the technique unnamed.
    convenience init?(code: String, settings: AppSettings, positions: TrainingPositions = .bundled, progress: TrainingProgress = .shared) {
        guard let pick = PracticePick(code: code), pick.index < positions.positions(for: pick.technique).count,
              Self.setup(for: pick, in: positions) != nil
        else { return nil }
        self.init(isRandom: true, from: pick.index, of: pick.technique, settings: settings, positions: positions, progress: progress, transform: true, seed: pick.seed, exact: true)
    }

    private init?(isRandom: Bool, from start: Int, of technique: TechniqueKind, settings: AppSettings, positions: TrainingPositions,
                  progress: TrainingProgress, transform: Bool, seed: UInt32? = nil, exact: Bool = false) {
        let found: (PracticePick, PracticeSetup)?
        if exact, let seed {
            let pick = PracticePick(technique: technique, index: start, seed: seed)
            found = Self.setup(for: pick, in: positions).map { (pick, $0) }
        } else {
            found = Self.firstSetup(of: technique, from: start, in: positions, transform: transform, seed: seed)
        }
        guard let (pick, setup) = found else { return nil }
        self.isRandom = isRandom
        self.pick = pick
        self.positions = positions
        self.settings = settings
        self.progress = progress
        game = GameModel(game: setup.game, settings: settings, followsMistakeLimitSetting: false)
        expected = setup.expected
        initialNotes = setup.game.notes
        prepare()
    }

    private static func setup(for pick: PracticePick, in positions: TrainingPositions, transform: Bool = true) -> PracticeSetup? {
        let list = positions.positions(for: pick.technique)
        guard pick.index < list.count else { return nil }
        return PracticeSetup(position: list[pick.index], technique: pick.technique, transform: transform ? .seeded(pick.seed) : .identity)
    }

    /// The first position from `start` on (wrapping around) that sets up correctly.
    private static func firstSetup(of technique: TechniqueKind, from start: Int, in positions: TrainingPositions, transform: Bool, seed: UInt32? = nil) -> (PracticePick, PracticeSetup)? {
        let count = positions.positions(for: technique).count
        for offset in 0..<count {
            let index = (start + offset) % count
            let pick = seed.map { PracticePick(technique: technique, index: index, seed: $0) } ?? .random(technique: technique, index: index)
            if let setup = setup(for: pick, in: positions, transform: transform) {
                return (pick, setup)
            }
        }
        return nil
    }

    private static func randomPick(in positions: TrainingPositions) -> PracticePick? {
        let techniques = TechniqueKind.allCases.filter { !positions.positions(for: $0).isEmpty }
        guard let technique = techniques.randomElement() else { return nil }
        return .random(technique: technique, index: Int.random(in: 0..<positions.positions(for: technique).count))
    }

    /// Points hints at the step's cells and remembers the position.
    private func prepare() {
        let cells = isPlacement ? expected.placements.map(\.cell) : expected.eliminations.map(\.cell)
        game.practiceFocus = (technique, cells, isPlacement)
        if !isRandom {
            progress.setCurrentPosition(positionIndex, of: technique)
        }
        keptMoves = []
        evaluate()
    }

    func nextPosition() {
        if isRandom {
            // A new technique each time, as far as there is more than one.
            for _ in 0..<8 {
                guard let next = Self.randomPick(in: positions) else { return }
                if load(next, exact: false) { return }
            }
        } else {
            load(PracticePick.random(technique: technique, index: positionIndex + 1), exact: false)
        }
    }

    /// The same position again, in a new transform.
    func retry() {
        load(PracticePick.random(technique: technique, index: positionIndex), exact: false)
    }

    /// The same position, as it was shown.
    func restart() {
        load(pick, exact: true)
    }

    @discardableResult
    private func load(_ next: PracticePick, exact: Bool) -> Bool {
        let found = exact
            ? Self.setup(for: next, in: positions).map { (next, $0) }
            : Self.firstSetup(of: next.technique, from: next.index, in: positions, transform: true, seed: next.seed)
        guard let (pick, setup) = found else { return false }
        self.pick = pick
        game = GameModel(game: setup.game, settings: settings, followsMistakeLimitSetting: false)
        expected = setup.expected
        initialNotes = setup.game.notes
        status = .working(done: 0, total: 0)
        loadID += 1
        prepare()
        return true
    }

    /// Compares the board with the technique's step. Called after every change.
    func evaluate() {
        let current = game.game
        let givens = current.puzzle.givens
        let solution = current.puzzle.solution
        let placements = Set(expected.placements.map { $0.cell * 10 + $0.digit })
        let removals = Set(expected.eliminations.flatMap { elimination in elimination.digits.map { elimination.cell * 10 + $0 } })

        let placed = Geometry.cells.compactMap { cell -> Int? in
            givens[cell] == 0 && current.values[cell] != 0 ? cell * 10 + current.values[cell] : nil
        }
        let removed = Geometry.cells.flatMap { cell -> [Int] in
            guard current.values[cell] == 0 else { return [] }
            return initialNotes[cell].subtracting(current.notes[cell]).map { cell * 10 + $0 }
        }
        // A move against the solution is wrong in either kind of practice.
        let againstSolution = placed.contains { solution[$0 / 10] != $0 % 10 } || removed.contains { solution[$0 / 10] == $0 % 10 }
        let expectedDone = placements.isEmpty
            ? !removals.isEmpty && removals.isSubset(of: Set(removed))
            : placements.isSubset(of: Set(placed))
        if expectedDone, !againstSolution, isRandom || (placed.count == placements.count && Set(removed).isSubset(of: removals)) {
            finish()
            return
        }
        let others = Set(placed + removed).subtracting(placements).subtracting(removals)
        if againstSolution || (!isRandom && !others.isEmpty) {
            status = .wrongMove
            return
        }
        if !others.subtracting(keptMoves).isEmpty {
            status = .otherSolution
            return
        }
        status = .working(done: Set(removed).intersection(removals).count, total: removals.count)
    }

    private func finish() {
        guard status != .solved else { return }
        status = .solved
        progress.markSolved(positionIndex, of: technique)
        if isRandom {
            progress.recordRandomSolved()
        }
    }

    func undoWrongMove() {
        game.undo()
        evaluate()
    }

    /// Random practice: keeps the other right moves made so far and goes on to the expected step.
    func continueToExpected() {
        let current = game.game
        keptMoves = Set(Geometry.cells.flatMap { cell -> [Int] in
            if current.values[cell] != 0, current.puzzle.givens[cell] == 0 { return [cell * 10 + current.values[cell]] }
            return initialNotes[cell].subtracting(current.notes[cell]).map { cell * 10 + $0 }
        })
        evaluate()
    }
}

/// Sessions are compared by identity, so one can drive a navigation destination.
extension PracticeModel: Hashable {
    nonisolated static func == (lhs: PracticeModel, rhs: PracticeModel) -> Bool {
        lhs === rhs
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
