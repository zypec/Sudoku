//
//  TrainingTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@MainActor
@Suite("Training")
struct TrainingTests {
    private let settings: AppSettings
    private let progress: TrainingProgress

    init() throws {
        settings = AppSettings(defaults: try #require(UserDefaults(suiteName: "TrainingTests.\(UUID().uuidString)")))
        progress = TrainingProgress(defaults: try #require(UserDefaults(suiteName: "TrainingTests.\(UUID().uuidString)")))
    }

    /// Every stored position, as stored and transformed, sets up with exactly its technique next.
    @Test(arguments: TechniqueKind.allCases)
    func positionsSetUpWithTheirTechniqueNext(technique: TechniqueKind) {
        let positions = TrainingPositions.bundled.positions(for: technique)
        var generator = SeededRandomNumberGenerator(seed: 7)
        for position in positions {
            #expect(PracticeSetup(position: position, technique: technique, transform: .identity) != nil, "\(technique)")
            let transform = PuzzleTransform.random(using: &generator)
            #expect(PracticeSetup(position: position, technique: technique, transform: transform) != nil, "\(technique) transformed")
        }
    }

    @Test func noPracticeWithoutPositions() {
        let empty = TrainingPositions(file: TrainingPositions.File(version: 1, positions: [:]))
        #expect(PracticeModel(technique: .xWing, settings: settings, positions: empty, progress: progress) == nil)
    }

    /// Removes the X-Wing's candidates one by one: progress counts up, then the position is solved.
    @Test func removingTheExpectedCandidatesSolvesThePosition() throws {
        let practice = try #require(PracticeModel(technique: .xWing, settings: settings, progress: progress, transform: false))
        guard case .step(let step, _) = HintFinder.hint(for: practice.game.game) else {
            Issue.record("Expected the X-Wing step")
            return
        }
        #expect(step.technique == .xWing)
        let removals = step.eliminations.flatMap { elimination in elimination.digits.map { (elimination.cell, $0) } }
        #expect(practice.status == .working(done: 0, total: removals.count))

        practice.game.toggleNotesMode()
        for (index, (cell, digit)) in removals.enumerated() {
            practice.game.select(cell)
            practice.game.input(digit)  // toggles the note off
            practice.evaluate()
            if index < removals.count - 1 {
                #expect(practice.status == .working(done: index + 1, total: removals.count))
            }
        }
        #expect(practice.status == .solved)
        #expect(progress.solvedPositions(of: .xWing).contains(practice.positionIndex))
    }

    @Test func removingAnotherNoteIsAWrongMoveThatCanBeUndone() throws {
        let practice = try #require(PracticeModel(technique: .xWing, settings: settings, progress: progress, transform: false))
        guard case .step(let step, _) = HintFinder.hint(for: practice.game.game) else { return }
        let targets = Set(step.eliminations.map(\.cell))
        let game = practice.game.game
        // A note the X-Wing doesn't touch.
        let cell = try #require(Geometry.cells.first { game.values[$0] == 0 && !targets.contains($0) && !game.notes[$0].isEmpty })
        let digit = try #require(game.notes[cell].min())

        practice.game.toggleNotesMode()
        practice.game.select(cell)
        practice.game.input(digit)
        practice.evaluate()
        #expect(practice.status == .wrongMove)

        practice.undoWrongMove()
        #expect(practice.status == .working(done: 0, total: step.eliminations.reduce(0) { $0 + $1.digits.count }))
    }

    @Test func placementTechniquesAreSolvedByTheDigit() throws {
        let practice = try #require(PracticeModel(technique: .hiddenSingle, settings: settings, progress: progress, transform: false))
        #expect(practice.isPlacement)
        guard case .step(let step, _) = HintFinder.hint(for: practice.game.game), let placement = step.placements.first else {
            Issue.record("Expected a hidden single")
            return
        }
        // A wrong digit first.
        let wrong = try #require(practice.game.game.notes[placement.cell].subtracting([placement.digit]).min())
        practice.game.select(placement.cell)
        practice.game.input(wrong)
        practice.evaluate()
        #expect(practice.status == .wrongMove)
        #expect(practice.game.game.mistakeLimit == nil)  // practice never ends on mistakes

        practice.undoWrongMove()
        practice.game.input(placement.digit)
        practice.evaluate()
        #expect(practice.status == .solved)
    }

    @Test func nextPositionLoadsANewGame() throws {
        let practice = try #require(PracticeModel(technique: .pointing, settings: settings, progress: progress))
        let first = practice.positionIndex
        let loadID = practice.loadID
        practice.nextPosition()
        #expect(practice.loadID == loadID + 1)
        #expect(practice.positionIndex != first)
        guard case .working(let done, _) = practice.status else {
            Issue.record("A new position starts untouched")
            return
        }
        #expect(done == 0)
    }

    @Test func applyingTheHintAlsoSolvesIt() throws {
        let practice = try #require(PracticeModel(technique: .nakedPair, settings: settings, progress: progress, transform: false))
        practice.game.requestHint()
        practice.game.applyHint()
        practice.evaluate()
        #expect(practice.status == .solved)
    }
}
