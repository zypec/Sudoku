//
//  GameScore.swift
//  Sudoku
//

/// Points earned for a finished game.
///
/// Every difficulty has a base; harder puzzles pay more. Speed against the puzzle's estimated time
/// adds or takes away up to half of it, each mistake, hint and revealed cell costs a share, and a
/// game without any of them earns a flawless bonus, and one played with every assist off a no-assists
/// bonus. A solved game always keeps at least a tenth of
/// its base. Lost games and games finished by auto solve earn nothing.
struct GameScore: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case base
        case speed
        case mistakes
        case hints
        case reveals
        case flawless
        case noAssists
    }

    /// One line of the breakdown, in points (negative for penalties).
    struct Line: Equatable, Sendable {
        let kind: Kind
        let points: Int
        /// How many mistakes, hints or reveals the line counts (0 for other lines).
        var count = 0
    }

    let lines: [Line]
    let total: Int

    static let basePoints: [Difficulty: Int] = [.easy: 1000, .medium: 2000, .hard: 3500, .expert: 5500, .master: 8000]

    init(result: GameResult) {
        guard result.isWin else {
            lines = []
            total = 0
            return
        }
        let base = Double(Self.basePoints[result.difficulty] ?? 1000)
        var lines = [Line(kind: .base, points: Int(base))]

        if let estimate = result.estimatedSeconds, estimate > 0, result.elapsedSeconds > 0 {
            // Twice as fast as the estimate gives about +41%, twice as slow about -29%.
            let ratio = Double(result.elapsedSeconds) / Double(estimate)
            let multiplier = min(1.5, max(0.5, 1 / ratio.squareRoot()))
            lines.append(Line(kind: .speed, points: Int((base * (multiplier - 1)).rounded())))
        }
        if result.mistakeCount > 0 {
            let share = min(0.5, 0.10 * Double(result.mistakeCount))
            lines.append(Line(kind: .mistakes, points: -Int((base * share).rounded()), count: result.mistakeCount))
        }
        if result.hintCount > 0 {
            let share = min(0.6, 0.08 * Double(result.hintCount))
            lines.append(Line(kind: .hints, points: -Int((base * share).rounded()), count: result.hintCount))
        }
        if result.revealCount > 0 {
            let share = min(0.6, 0.15 * Double(result.revealCount))
            lines.append(Line(kind: .reveals, points: -Int((base * share).rounded()), count: result.revealCount))
        }
        if result.mistakeCount == 0, result.hintCount == 0, result.revealCount == 0 {
            lines.append(Line(kind: .flawless, points: Int((base * 0.2).rounded())))
        }
        if result.withoutAssists {
            lines.append(Line(kind: .noAssists, points: Int((base * 0.15).rounded())))
        }

        let sum = lines.reduce(0) { $0 + $1.points }
        let floor = Int(base * 0.1)
        // Rounded to tens so totals read cleanly.
        total = (max(floor, sum) + 5) / 10 * 10
        self.lines = lines
    }
}

extension GameResult {
    var score: GameScore {
        GameScore(result: self)
    }
}
