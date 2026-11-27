//
//  StatisticsTests.swift
//  SudokuTests
//

import Foundation
import SwiftData
import Testing
@testable import Sudoku

@Suite("Statistics")
struct StatisticsTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func result(_ minute: Int, solved: Bool = true, seconds: Int = 600, hints: Int = 0, autoSolved: Int = 0,
                        required: [TechniqueKind] = [], hinted: [TechniqueKind] = []) -> GameResult {
        GameResult(
            finishedAt: start.addingTimeInterval(Double(minute) * 60),
            difficulty: .medium,
            isSolved: solved,
            elapsedSeconds: seconds,
            hintCount: hints,
            autoSolvedSteps: autoSolved,
            requiredTechniques: required,
            hintedTechniques: hinted
        )
    }

    // MARK: Summary

    @Test func emptySummary() {
        let summary = StatsSummary(results: [])
        #expect(summary.played == 0)
        #expect(summary.winRate == nil)
        #expect(summary.bestSeconds == nil)
        #expect(summary.averageSeconds == nil)
        #expect(summary.hintsPerGame == nil)
    }

    @Test func summaryCountsOnlyRealWins() {
        let results = [
            result(1, seconds: 500, hints: 2),
            result(2, seconds: 700),
            result(3, solved: false, seconds: 300),
            result(4, seconds: 100, autoSolved: 40),  // auto solved: not a win, time ignored
            result(5, seconds: 900, hints: 1),
        ]
        // Order of the input doesn't matter.
        let summary = StatsSummary(results: results.reversed())
        #expect(summary.played == 5)
        #expect(summary.wins == 3)
        #expect(summary.winRate == 0.6)
        #expect(summary.bestSeconds == 500)
        #expect(summary.averageSeconds == 700)
        #expect(summary.hintsPerGame == 0.6)
        // Wins at 1, 2, then a loss and an auto solve, then a win.
        #expect(summary.bestStreak == 2)
        #expect(summary.currentStreak == 1)
    }

    @Test func techniqueStatsCountPuzzlesSolvedWithoutAHintForTheTechnique() {
        let results = [
            result(1, required: [.hiddenSingle, .xWing]),
            result(2, required: [.hiddenSingle, .xWing], hinted: [.xWing]),
            result(3, solved: false, required: [.hiddenSingle, .xWing]),
            result(4, required: [.hiddenSingle]),
        ]
        let stats = TechniqueStat.all(from: results)
        #expect(stats.map(\.technique) == [.hiddenSingle, .xWing])
        #expect(stats[0] == TechniqueStat(technique: .hiddenSingle, needed: 4, solvedAlone: 3))
        #expect(stats[1] == TechniqueStat(technique: .xWing, needed: 3, solvedAlone: 1))
    }

    // MARK: Score

    private func scored(_ difficulty: Difficulty, seconds: Int = 1200, estimate: Int? = 1200, mistakes: Int = 0, hints: Int = 0,
                        reveals: Int = 0, autoSolved: Int = 0, solved: Bool = true) -> GameScore {
        GameResult(finishedAt: start, difficulty: difficulty, isSolved: solved, elapsedSeconds: seconds, mistakeCount: mistakes,
                   hintCount: hints, revealCount: reveals, autoSolvedSteps: autoSolved, estimatedSeconds: estimate).score
    }

    @Test func flawlessGameAtTheEstimateEarnsBasePlusBonus() {
        let score = scored(.hard)
        #expect(score.total == 4200)  // 3500 + 0 speed + 700 flawless
        #expect(score.lines.map(\.kind) == [.base, .speed, .flawless])
    }

    @Test func gamesWithoutAssistsEarnABonus() {
        var result = GameResult(finishedAt: start, difficulty: .hard, isSolved: true, elapsedSeconds: 1200, estimatedSeconds: 1200)
        result.withoutAssists = true
        #expect(result.score.total == 4730)  // 3500 + 700 flawless + 525 no assists, rounded to tens
        #expect(result.score.lines.map(\.kind) == [.base, .speed, .flawless, .noAssists])
    }

    @Test func anAssistOnAtAnyPointEndsTheNoAssistsBonus() throws {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        var game = SudokuGame(puzzle: puzzle, mistakeLimit: nil)
        #expect(!game.playedWithoutAssists)  // nothing noted yet
        game.noteAssists(false)
        #expect(game.playedWithoutAssists)
        game.noteAssists(true)
        game.noteAssists(false)
        #expect(!game.playedWithoutAssists)
    }

    @Test func harderPuzzlesPayMore() {
        let totals = Difficulty.allCases.map { scored($0).total }
        #expect(totals == totals.sorted())
        #expect(Set(totals).count == totals.count)
    }

    @Test func speedMistakesAndHintsMoveTheScore() {
        let base = scored(.expert).total
        #expect(scored(.expert, seconds: 600).total > base)
        #expect(scored(.expert, seconds: 4800).total < base)
        #expect(scored(.expert, mistakes: 1).total < base)
        #expect(scored(.expert, hints: 2).total < scored(.expert, hints: 1).total)
        #expect(scored(.expert, reveals: 1).total < base)
        // Penalties are capped and a solved game keeps a floor.
        #expect(scored(.expert, seconds: 100_000, mistakes: 20, hints: 20, reveals: 20).total == 550)
    }

    @Test func lostAndAutoSolvedGamesEarnNothing() {
        #expect(scored(.master, solved: false).total == 0)
        #expect(scored(.master, autoSolved: 10).total == 0)
        #expect(scored(.master, estimate: nil).total == 9600)  // no estimate: no speed line
    }

    @Test func summaryAddsUpScoresOfWins() {
        let results = [result(1, seconds: 600), result(2, solved: false), result(3, seconds: 600, autoSolved: 5)]
        let summary = StatsSummary(results: results)
        #expect(summary.totalScore == results[0].score.total)
        #expect(summary.bestScore == results[0].score.total)
    }

    // MARK: Estimates

    @Test func shareOfSlowerPlayersFollowsTheTime() {
        let estimate = 1200
        #expect(abs(SolveTimeEstimate.shareOfSlowerPlayers(than: estimate, estimate: estimate) - 0.5) < 0.0001)
        let fast = SolveTimeEstimate.shareOfSlowerPlayers(than: 600, estimate: estimate)
        let slow = SolveTimeEstimate.shareOfSlowerPlayers(than: 2400, estimate: estimate)
        #expect(fast > 0.9)
        #expect(slow < 0.1)
        #expect(SolveTimeEstimate.shareOfSlowerPlayers(than: 900, estimate: estimate) > SolveTimeEstimate.shareOfSlowerPlayers(than: 1000, estimate: estimate))
    }

    /// Generated puzzles carry an estimate near the calibration target and the techniques they need.
    @Test(arguments: [(Difficulty.easy, 6.0), (.medium, 12), (.hard, 22), (.expert, 35), (.master, 55)])
    func generatedPuzzlesCarryAnEstimate(difficulty: Difficulty, targetMinutes: Double) throws {
        var minutes: [Double] = []
        for seed in UInt64(200)..<203 {
            var generator = SeededRandomNumberGenerator(seed: seed)
            let puzzle = PuzzleGenerator.generate(difficulty, using: &generator)
            let estimate = try #require(puzzle.estimatedSeconds)
            minutes.append(Double(estimate) / 60)
            let required = try #require(puzzle.requiredTechniques)
            #expect(required.contains { $0.level == difficulty.level })
            #expect(required.allSatisfy { $0.level <= difficulty.level })
        }
        let average = minutes.reduce(0, +) / Double(minutes.count)
        // A model, not a measurement: the average should land in the right neighborhood.
        #expect(average > targetMinutes * 0.5 && average < targetMinutes * 1.6, "\(difficulty): \(average) min")
    }

    // MARK: Persistence

    @Test func gamesSavedBeforeStatisticsStillLoad() throws {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        var game = SudokuGame(puzzle: puzzle, mistakeLimit: 3)
        game.registerHint(for: .hiddenSingle)
        let data = try JSONEncoder().encode(game)
        // Drop the fields added for statistics, as in a save from an older version.
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["hintedTechniques"] = nil
        json["autoSolvedSteps"] = nil
        var puzzleJSON = try #require(json["puzzle"] as? [String: Any])
        puzzleJSON["estimatedSeconds"] = nil
        puzzleJSON["requiredTechniques"] = nil
        json["puzzle"] = puzzleJSON

        let old = try JSONDecoder().decode(SudokuGame.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.hintedTechniques == nil)
        #expect(old.puzzle.estimatedSeconds == nil)
        #expect(old.hintCount == 1)
    }

    @MainActor
    @Test func finishedGamesAreRecordedOnce() throws {
        let container = try ModelContainer(for: GameRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let settings = AppSettings(defaults: try #require(UserDefaults(suiteName: "StatisticsTests.\(UUID().uuidString)")))
        var generator = SeededRandomNumberGenerator(seed: 1)
        let puzzle = PuzzleGenerator.generate(.easy, using: &generator)
        let model = GameModel(game: SudokuGame(puzzle: puzzle, mistakeLimit: 3), settings: settings, recorder: GameRecorder(context: context))

        // With notes written, the smart hint is a step of logic, so its technique is recorded.
        model.fillNotes()
        model.requestHint()
        model.applyHint()
        #expect(try context.fetch(FetchDescriptor<GameRecord>()).isEmpty)

        // Fill every remaining cell.
        for cell in Geometry.cells where model.game.values[cell] == 0 {
            model.select(cell)
            model.input(puzzle.solution[cell])
        }
        #expect(model.game.isSolved)
        model.undo()  // ignored once finished, and must not record again

        let records = try context.fetch(FetchDescriptor<GameRecord>())
        #expect(records.count == 1)
        let result = try #require(records.first?.result)
        #expect(result.isWin)
        #expect(result.difficulty == .easy)
        #expect(result.hintCount == 1)
        #expect(result.hintedTechniques.count == 1)
        #expect(result.estimatedSeconds == puzzle.estimatedSeconds)
        #expect(result.requiredTechniques == puzzle.requiredTechniques)
        #expect(model.shareOfSlowerPlayers != nil)
    }

    @MainActor
    @Test func lostGamesAreRecordedAsLosses() throws {
        let container = try ModelContainer(for: GameRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let settings = AppSettings(defaults: try #require(UserDefaults(suiteName: "StatisticsTests.\(UUID().uuidString)")))
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        // The default setting is three mistakes.
        let model = GameModel(game: SudokuGame(puzzle: puzzle, mistakeLimit: 3), settings: settings, recorder: GameRecorder(context: context))
        model.select(2)  // solution 4
        for wrong in [1, 2, 9] {
            model.input(wrong)
        }
        #expect(model.game.isLost)

        let records = try context.fetch(FetchDescriptor<GameRecord>())
        #expect(records.count == 1)
        #expect(records.first?.isSolved == false)
        #expect(model.shareOfSlowerPlayers == nil)
    }
}
