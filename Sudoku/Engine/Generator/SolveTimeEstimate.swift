//
//  SolveTimeEstimate.swift
//  Sudoku
//

import Foundation

/// Estimates how long a typical player needs for a puzzle, from the steps the logical solver takes.
///
/// There is no player data behind this yet, so it is a model: every step costs a base time for its
/// technique level, scaled by how crowded the board is when the step is found (spotting a pattern
/// among 250 candidates takes longer than among 40, the same idea sudokuwiki.org uses for grading).
/// The level weights are calibrated so that generated puzzles average roughly
/// Easy 6, Medium 12, Hard 22, Expert 35 and Master 55 minutes.
///
/// Solve times of a group of players are right-skewed, so they are modelled as log-normal around
/// the estimate; that turns a finishing time into an estimated share of slower players.
enum SolveTimeEstimate {
    /// Seconds per step at the reference crowding, by technique level 1...5.
    /// Calibrated level by level on generated puzzles: Easy puzzles fix level 1, Medium level 2, and
    /// so on (see `SolveTimeEstimateTests`).
    static let secondsPerStep: [Int: Double] = [1: 30, 2: 205, 3: 380, 4: 520, 5: 560]

    /// Candidate count that a step's base time refers to.
    private static let referenceCandidates = 200.0

    /// Spread of the log-normal model: about two thirds of players fall within a factor of 1.65
    /// of the estimate.
    static let spread = 0.5

    /// Estimated seconds for a typical player to solve `givens` with the steps of `result`.
    static func seconds(givens: [Digit], result: SolveResult) -> Int {
        let crowding = crowdingByLevel(givens: givens, result: result)
        let total = crowding.reduce(0.0) { sum, entry in
            sum + (secondsPerStep[entry.key] ?? 0) * entry.value
        }
        return max(60, Int(total.rounded()))
    }

    /// Per technique level, the sum over its steps of the board's candidate count relative to the
    /// reference. This is the model's only input; the estimate is a weighted sum of it.
    static func crowdingByLevel(givens: [Digit], result: SolveResult) -> [Int: Double] {
        var board = Board(values: givens)
        var crowding: [Int: Double] = [:]
        for step in result.steps {
            let candidates = Double(board.emptyCells.reduce(0) { $0 + board.candidates(at: $1).count })
            crowding[step.technique.level, default: 0] += candidates / referenceCandidates
            board.apply(step)
        }
        return crowding
    }

    /// Estimated share (0...1) of players slower than `seconds` on a puzzle estimated at `estimate`.
    static func shareOfSlowerPlayers(than seconds: Int, estimate: Int) -> Double {
        guard seconds > 0, estimate > 0 else { return 0 }
        let z = (log(Double(seconds)) - log(Double(estimate))) / spread
        // 1 - Φ(z), where Φ is the standard normal distribution function.
        return 0.5 * erfc(z / 2.0.squareRoot())
    }
}
