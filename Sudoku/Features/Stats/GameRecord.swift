//
//  GameRecord.swift
//  Sudoku
//

import Foundation
import SwiftData

/// The outcome of one finished game, as plain data. Statistics are computed from these, so they
/// can be tested without a database.
struct GameResult: Hashable, Sendable {
    var finishedAt: Date
    var difficulty: Difficulty
    var isSolved: Bool
    var elapsedSeconds: Int
    var mistakeCount: Int = 0
    var hintCount: Int = 0
    var revealCount: Int = 0
    var autoSolvedSteps: Int = 0
    var estimatedSeconds: Int?
    var requiredTechniques: [TechniqueKind] = []
    var hintedTechniques: [TechniqueKind] = []

    /// Solved by the player: auto solve didn't do any of it.
    var isWin: Bool {
        isSolved && autoSolvedSteps == 0
    }
}

/// A finished game, stored with SwiftData. Enums are stored as raw values so that adding a case
/// later never breaks the store.
@Model
final class GameRecord {
    var finishedAt: Date
    var difficultyRaw: Int
    var isSolved: Bool
    var elapsedSeconds: Int
    var mistakeCount: Int
    var hintCount: Int
    var revealCount: Int
    var autoSolvedSteps: Int
    var estimatedSeconds: Int?
    var requiredTechniquesRaw: [String]
    var hintedTechniquesRaw: [String]
    /// Whether this was a daily puzzle; normal games are `false`.
    var isDaily: Bool
    /// The daily puzzle's day (`DailyPuzzle`), for a daily game.
    var dailyDay: Int?

    init(_ result: GameResult, dailyDay: Int? = nil) {
        finishedAt = result.finishedAt
        difficultyRaw = result.difficulty.rawValue
        isSolved = result.isSolved
        elapsedSeconds = result.elapsedSeconds
        mistakeCount = result.mistakeCount
        hintCount = result.hintCount
        revealCount = result.revealCount
        autoSolvedSteps = result.autoSolvedSteps
        estimatedSeconds = result.estimatedSeconds
        requiredTechniquesRaw = result.requiredTechniques.map(\.rawValue)
        hintedTechniquesRaw = result.hintedTechniques.map(\.rawValue)
        isDaily = dailyDay != nil
        self.dailyDay = dailyDay
    }

    var result: GameResult {
        GameResult(
            finishedAt: finishedAt,
            difficulty: Difficulty(rawValue: difficultyRaw) ?? .easy,
            isSolved: isSolved,
            elapsedSeconds: elapsedSeconds,
            mistakeCount: mistakeCount,
            hintCount: hintCount,
            revealCount: revealCount,
            autoSolvedSteps: autoSolvedSteps,
            estimatedSeconds: estimatedSeconds,
            requiredTechniques: requiredTechniquesRaw.compactMap(TechniqueKind.init(rawValue:)),
            hintedTechniques: hintedTechniquesRaw.compactMap(TechniqueKind.init(rawValue:))
        )
    }
}

extension GameResult {
    /// The result of a game that has just finished.
    init(game: SudokuGame, finishedAt: Date = .now) {
        self.init(
            finishedAt: finishedAt,
            difficulty: game.puzzle.difficulty,
            isSolved: game.isSolved,
            elapsedSeconds: game.elapsedSeconds,
            mistakeCount: game.totalMistakes,
            hintCount: game.hintCount,
            revealCount: game.revealCount,
            autoSolvedSteps: game.autoSolvedSteps ?? 0,
            estimatedSeconds: game.puzzle.estimatedSeconds,
            requiredTechniques: game.puzzle.requiredTechniques ?? [],
            hintedTechniques: game.hintedTechniques ?? []
        )
    }
}

/// Saves finished games. Owned by whoever creates game models (the home screen).
@MainActor
final class GameRecorder {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func record(_ game: SudokuGame, dailyDay: Int? = nil) -> GameRecord {
        let record = GameRecord(GameResult(game: game), dailyDay: dailyDay)
        context.insert(record)
        try? context.save()
        return record
    }

    /// Takes back a recorded loss when the player plays on after it.
    func discard(_ record: GameRecord) {
        context.delete(record)
        try? context.save()
    }
}
