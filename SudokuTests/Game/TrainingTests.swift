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
        // Singles are practiced without notes.
        let hasNotes = practice.game.game.notes.contains { !$0.isEmpty }
        #expect(!hasNotes)
        // A wrong digit first.
        let wrong = placement.digit % 9 + 1
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

    @Test func hintsInPracticeOnlyPointAtTheCells() throws {
        let practice = try #require(PracticeModel(technique: .nakedPair, settings: settings, progress: progress, transform: false))
        guard case .step(let step, _) = HintFinder.hint(for: practice.game.game) else { return }
        practice.game.requestHint()
        let hint = try #require(practice.game.activeHint)
        #expect(hint.count == 1)
        #expect(hint.hint.steps.isEmpty)  // nothing to apply or play
        for elimination in step.eliminations {
            #expect(hint.page.highlights.style(for: elimination.cell)?.fill == .pattern)
        }
    }

    @Test func practiceResumesWhereThePlayerLeftOff() throws {
        let practice = try #require(PracticeModel(technique: .pointing, settings: settings, progress: progress))
        practice.nextPosition()
        practice.nextPosition()
        let reached = practice.positionIndex
        let resumed = try #require(PracticeModel(technique: .pointing, settings: settings, progress: progress))
        #expect(resumed.positionIndex == reached)
    }

    // MARK: Random practice and codes

    @Test func aTrainingCodeNamesItsPosition() throws {
        let pick = PracticePick(technique: .xyWing, index: 17, seed: 987_654_321)
        #expect(pick.code.count == 11)
        #expect(pick.code.hasPrefix("T"))
        #expect(PracticePick(code: pick.code) == pick)
        #expect(PracticePick(code: pick.code.lowercased().replacingOccurrences(of: "-", with: "")) == pick)
        #expect(PracticePick(code: "H7K-2M4-Q9X") == nil)  // a puzzle code, not a training one
    }

    @Test func aCodeOpensTheSamePosition() throws {
        let first = try #require(PracticeModel(randomWith: settings, progress: progress))
        let again = try #require(PracticeModel(code: first.pick.code, settings: settings, progress: progress))
        #expect(again.pick == first.pick)
        #expect(again.game.game.values == first.game.game.values)
        #expect(again.isRandom)
    }

    /// In random practice a right move that isn't the expected step is offered to keep; the expected
    /// step still solves the position, and the day's count goes up.
    @Test func randomPracticeTakesOtherRightMoves() throws {
        let pick = PracticePick(technique: .xWing, index: 0, seed: 1)
        let practice = try #require(PracticeModel(code: pick.code, settings: settings, progress: progress))
        guard case .step(let step, _) = HintFinder.hint(for: practice.game.game) else {
            Issue.record("Expected the X-Wing step")
            return
        }
        // A right digit somewhere the X-Wing doesn't touch, and not its digit: placing that would
        // clear its eliminations by itself.
        let game = practice.game.game
        let touched = Set(step.eliminations.map(\.cell))
        let digits = step.eliminations.reduce(CandidateSet.empty) { $0.union($1.digits) }
        let other = try #require(Geometry.cells.first {
            game.values[$0] == 0 && !touched.contains($0) && !digits.contains(game.puzzle.solution[$0])
        })
        practice.game.select(other)
        practice.game.input(game.puzzle.solution[other])
        practice.evaluate()
        #expect(practice.status == .otherSolution)
        practice.continueToExpected()
        #expect(practice.status != .otherSolution)

        practice.game.toggleNotesMode()
        for elimination in step.eliminations {
            for digit in elimination.digits where practice.game.game.notes[elimination.cell].contains(digit) {
                practice.game.select(elimination.cell)
                practice.game.input(digit)
            }
        }
        practice.evaluate()
        #expect(practice.status == .solved)
        #expect(progress.randomSolved() == 1)
        #expect(progress.randomDailyAverage() == 1)

        practice.restart()
        #expect(practice.status != .solved)
        #expect(practice.pick == pick)
    }

    @Test func aWrongMoveIsWrongInRandomPracticeToo() throws {
        let practice = try #require(PracticeModel(code: PracticePick(technique: .xWing, index: 0, seed: 1).code, settings: settings, progress: progress))
        let game = practice.game.game
        let cell = try #require(Geometry.cells.first { game.values[$0] == 0 })
        let wrong = try #require(Geometry.digits.first { $0 != game.puzzle.solution[cell] })
        practice.game.select(cell)
        practice.game.input(wrong)
        practice.evaluate()
        #expect(practice.status == .wrongMove)
    }
}
