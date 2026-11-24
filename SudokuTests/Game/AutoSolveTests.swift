//
//  AutoSolveTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@MainActor
@Suite("Auto solve")
struct AutoSolveTests {
    private let settings: AppSettings

    init() throws {
        settings = AppSettings(defaults: try #require(UserDefaults(suiteName: "AutoSolveTests.\(UUID().uuidString)")))
    }

    private func model(_ difficulty: Difficulty = .medium, seed: UInt64 = 1) -> GameModel {
        var generator = SeededRandomNumberGenerator(seed: seed)
        let game = SudokuGame(puzzle: PuzzleGenerator.generate(difficulty, using: &generator), mistakeLimit: 3)
        return GameModel(game: game, settings: settings)
    }

    /// Presses "Next Step" until auto solve ends, so the test doesn't wait for the timer.
    private func stepThrough(_ model: GameModel, limit: Int = 3000) async throws {
        for _ in 0..<limit where model.autoSolve != nil {
            model.autoSolveNextStep()
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    @Test(arguments: [(Difficulty.medium, UInt64(1)), (.hard, 2)])
    func solvesThePuzzleAndCountsHints(difficulty: Difficulty, seed: UInt64) async throws {
        let model = model(difficulty, seed: seed)
        model.startAutoSolve()
        #expect(model.autoSolve != nil)
        #expect(model.isShowingHintHighlights)

        try await stepThrough(model)
        #expect(model.game.isSolved)
        #expect(model.game.mistakeCount == 0)
        #expect(model.game.hintCount > 0)
        #expect(model.autoSolve == nil)
    }

    @Test func showsTheStepBeforeApplyingIt() async throws {
        settings.autoSolveSpeed = .half
        let model = model()
        let before = model.game.values
        model.startAutoSolve()
        try await Task.sleep(for: .milliseconds(200))

        let state = try #require(model.autoSolve)
        #expect(state.page?.kind == .result)
        #expect(state.page?.highlights.isEmpty == false)
        #expect(state.appliedSteps == 0)
        #expect(model.game.values == before)
        model.stopAutoSolve()
    }

    @Test func pauseHoldsTheStepOnScreen() async throws {
        settings.autoSolveSpeed = .quadruple
        let model = model()
        model.startAutoSolve()
        model.toggleAutoSolvePause()
        #expect(model.autoSolve?.isPaused == true)

        // Longer than one step at 4x.
        try await Task.sleep(for: .milliseconds(700))
        #expect(model.autoSolve?.appliedSteps == 0)

        // "Next Step" still works while paused, one step at a time.
        model.autoSolveNextStep()
        try await Task.sleep(for: .milliseconds(150))
        #expect(model.autoSolve?.appliedSteps == 1)
        #expect(model.autoSolve?.isPaused == true)
        model.stopAutoSolve()
    }

    @Test func wrongEntriesAreErasedFirst() async throws {
        let model = model()
        let cell = try #require(Geometry.cells.first { model.game.values[$0] == 0 })
        let wrong = model.game.puzzle.solution[cell] % 9 + 1
        model.select(cell)
        model.input(wrong)
        #expect(!model.game.incorrectCells.isEmpty)

        model.startAutoSolve()
        try await Task.sleep(for: .milliseconds(50))
        guard case .incorrectEntries? = model.autoSolve?.hint else {
            Issue.record("Expected the wrong entry to be handled first")
            return
        }
        model.autoSolveNextStep()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.game.incorrectCells.isEmpty)
        model.stopAutoSolve()
    }

    @Test func stopLeavesTheGameAsItIs() async throws {
        let model = model()
        model.startAutoSolve()
        model.autoSolveNextStep()
        try await Task.sleep(for: .milliseconds(100))
        let values = model.game.values
        model.stopAutoSolve()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.autoSolve == nil)
        #expect(!model.isShowingHintHighlights)
        #expect(model.game.values == values)
    }

    @Test func speedIsRemembered() throws {
        let defaults = try #require(UserDefaults(suiteName: "AutoSolveTests.\(UUID().uuidString)"))
        AppSettings(defaults: defaults).autoSolveSpeed = .double
        #expect(AppSettings(defaults: defaults).autoSolveSpeed == .double)
        #expect(AutoSolveSpeed.quadruple.stepDuration < AutoSolveSpeed.normal.stepDuration)
    }
}
