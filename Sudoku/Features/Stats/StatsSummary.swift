//
//  StatsSummary.swift
//  Sudoku
//

/// Statistics over a set of finished games (all of them, or one difficulty).
///
/// A *win* is a solved game where auto solve did none of the work. Times (best, average) only
/// count wins; a streak is a run of consecutive wins, broken by a loss or an auto-solved game.
struct StatsSummary: Equatable {
    let played: Int
    let wins: Int
    let bestSeconds: Int?
    let averageSeconds: Int?
    let currentStreak: Int
    let bestStreak: Int
    let hintsPerGame: Double?
    /// Points from every game (see `GameScore`).
    let totalScore: Int
    let bestScore: Int?

    init(results: [GameResult]) {
        let ordered = results.sorted { $0.finishedAt < $1.finishedAt }
        let winTimes = ordered.filter(\.isWin).map(\.elapsedSeconds)
        played = ordered.count
        wins = winTimes.count
        bestSeconds = winTimes.min()
        averageSeconds = winTimes.isEmpty ? nil : winTimes.reduce(0, +) / winTimes.count
        hintsPerGame = ordered.isEmpty ? nil : Double(ordered.reduce(0) { $0 + $1.hintCount }) / Double(ordered.count)
        let scores = ordered.filter(\.isWin).map(\.score.total)
        totalScore = scores.reduce(0, +)
        bestScore = scores.max()

        var current = 0
        var best = 0
        for result in ordered {
            current = result.isWin ? current + 1 : 0
            best = max(best, current)
        }
        currentStreak = current
        bestStreak = best
    }

    /// Share of games won, `nil` before the first game.
    var winRate: Double? {
        played == 0 ? nil : Double(wins) / Double(played)
    }
}

/// How the player does with one technique: how many finished puzzles needed it, and in how many of
/// those the player won without asking for a hint about it.
struct TechniqueStat: Equatable, Identifiable {
    let technique: TechniqueKind
    let needed: Int
    let solvedAlone: Int

    var id: TechniqueKind { technique }

    var successRate: Double {
        needed == 0 ? 0 : Double(solvedAlone) / Double(needed)
    }

    /// One entry per technique that some puzzle needed, easiest first.
    static func all(from results: [GameResult]) -> [TechniqueStat] {
        TechniqueKind.allCases.compactMap { technique in
            let needing = results.filter { $0.requiredTechniques.contains(technique) }
            guard !needing.isEmpty else { return nil }
            let alone = needing.count { $0.isWin && !$0.hintedTechniques.contains(technique) }
            return TechniqueStat(technique: technique, needed: needing.count, solvedAlone: alone)
        }
    }
}
