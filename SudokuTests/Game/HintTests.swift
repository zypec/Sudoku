//
//  HintTests.swift
//  SudokuTests
//

import Testing
@testable import Sudoku

@Suite("Hints")
struct HintTests {
    private func easyGame() throws -> SudokuGame {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        return SudokuGame(puzzle: puzzle, mistakeLimit: 3)
    }

    private func generatedGame(_ difficulty: Difficulty, seed: UInt64) -> SudokuGame {
        var generator = SeededRandomNumberGenerator(seed: seed)
        return SudokuGame(puzzle: PuzzleGenerator.generate(difficulty, using: &generator), mistakeLimit: 3)
    }

    /// Keeps asking for hints and applying them. Returns how many hints were needed.
    private func solveWithHints(_ game: inout SudokuGame) -> Int {
        var count = 0
        while !game.isFinished, count < 500 {
            guard case .step(let step, _) = HintFinder.hint(for: game) else { break }
            game.apply(step)
            count += 1
        }
        return count
    }

    // MARK: Finding hints

    @Test func incorrectEntriesComeFirst() throws {
        var game = try easyGame()
        game.enter(1, at: 2) // solution is 4
        #expect(HintFinder.hint(for: game) == .incorrectEntries([2]))
    }

    @Test func stepHintsAgreeWithTheSolution() throws {
        let game = try easyGame()
        guard case .step(let step, _) = HintFinder.hint(for: game) else {
            Issue.record("Expected a step hint")
            return
        }
        #expect(step.technique.level == 1)
        for placement in step.placements {
            #expect(game.puzzle.solution[placement.cell] == placement.digit)
        }
    }

    @Test func consistentNotesNarrowTheCandidates() throws {
        var game = try easyGame()
        // Cell 2 has candidates {1, 2, 4} and solution 4. Noting only 4 is consistent.
        game.toggleNote(4, at: 2)
        #expect(HintFinder.candidateBoard(for: game).candidates(at: 2) == [4])
    }

    @Test func inconsistentNotesAreIgnored() throws {
        var game = try easyGame()
        // Noting only 1 and 2 excludes the solution 4, so notes can't be trusted anywhere.
        game.toggleNote(1, at: 2)
        game.toggleNote(2, at: 2)
        game.toggleNote(6, at: 3)
        #expect(HintFinder.candidateBoard(for: game).candidates(at: 2) == [1, 2, 4])
    }

    @Test func noHintBeyondKnownTechniques() throws {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.inkala),
            solution: try TestPuzzles.values(TestPuzzles.inkalaSolution),
            difficulty: .master
        )
        #expect(HintFinder.hint(for: SudokuGame(puzzle: puzzle, mistakeLimit: nil)) == .unavailable)
    }

    // MARK: Applying hints

    @Test(arguments: [(Difficulty.easy, UInt64(1)), (.medium, 1), (.medium, 2), (.medium, 3), (.hard, 1), (.hard, 2)])
    func applyingHintsSolvesThePuzzleWithoutNotes(difficulty: Difficulty, seed: UInt64) {
        var game = generatedGame(difficulty, seed: seed)
        let hints = solveWithHints(&game)
        #expect(game.isSolved)
        #expect(game.mistakeCount == 0)
        // Every empty cell needs one placement; eliminations add a few more steps.
        #expect(hints >= game.puzzle.givens.count { $0 == 0 })
    }

    @Test func applyingHintsSolvesThePuzzleWithFullNotes() {
        var game = generatedGame(.medium, seed: 4)
        game.fillNotes()
        _ = solveWithHints(&game)
        #expect(game.isSolved)
        #expect(game.mistakeCount == 0)
    }

    @Test func eliminationHintsAreRememberedWithoutNotes() {
        var game = generatedGame(.medium, seed: 1)
        // Play until the first elimination step.
        while case .step(let step, _) = HintFinder.hint(for: game), step.eliminations.isEmpty {
            game.apply(step)
        }
        guard case .step(let elimination, _) = HintFinder.hint(for: game) else {
            Issue.record("Expected an elimination step")
            return
        }
        game.apply(elimination)
        for item in elimination.eliminations {
            #expect(game.deducedEliminations[item.cell].isSuperset(of: item.digits))
        }
        // The same deduction is not offered again.
        guard case .step(let next, _) = HintFinder.hint(for: game) else { return }
        #expect(next != elimination)
    }

    @Test func eliminationHintsUpdateNotesAndCanBeUndone() {
        var game = generatedGame(.medium, seed: 1)
        game.fillNotes()
        while case .step(let step, _) = HintFinder.hint(for: game), step.eliminations.isEmpty {
            game.apply(step)
        }
        guard case .step(let elimination, _) = HintFinder.hint(for: game), let first = elimination.eliminations.first else {
            Issue.record("Expected an elimination step")
            return
        }
        #expect(game.notes[first.cell].isSuperset(of: first.digits))
        game.apply(elimination)
        #expect(game.notes[first.cell].intersection(first.digits).isEmpty)
        game.undo()
        #expect(game.notes[first.cell].isSuperset(of: first.digits))
    }

    // MARK: Reveal and erase

    @Test func revealWritesTheSolutionWithoutAMistake() throws {
        var game = try easyGame()
        game.toggleNote(4, at: 3) // same row as cell 2
        let revealed = game.reveal(at: 2)
        #expect(revealed)
        #expect(game.values[2] == 4)
        #expect(game.revealCount == 1)
        #expect(game.mistakeCount == 0)
        #expect(!game.notes[3].contains(4))

        let again = game.reveal(at: 2)
        let onGiven = game.reveal(at: 0)
        #expect(!again)
        #expect(!onGiven)
    }

    @Test func revealFixesAWrongEntry() throws {
        var game = try easyGame()
        game.enter(1, at: 2)
        game.reveal(at: 2)
        #expect(game.values[2] == 4)
        #expect(game.incorrectCells.isEmpty)
    }

    @Test func eraseIncorrectEntriesKeepsCorrectOnes() throws {
        var game = try easyGame()
        game.enter(4, at: 2) // correct
        game.enter(1, at: 3) // wrong
        let erased = game.eraseIncorrectEntries()
        #expect(erased)
        #expect(game.values[2] == 4)
        #expect(game.values[3] == 0)
    }

    // MARK: Wording

    /// Every technique has wording for every stage, with all placeholders filled in.
    @Test(arguments: [(Difficulty.hard, UInt64(1)), (.hard, 2), (.hard, 3)])
    func everyStepOfAHardPuzzleHasWording(difficulty: Difficulty, seed: UInt64) {
        var game = generatedGame(difficulty, seed: seed)
        var seen = Set<TechniqueKind>()
        while !game.isFinished, case .step(let step, _) = HintFinder.hint(for: game) {
            let hint = HintFinder.hint(for: game)
            seen.insert(step.technique)
            for stage in HintStage.allCases {
                let message = HintText.message(for: hint, stage: stage)
                #expect(!message.isEmpty, "\(step.technique) has no text for \(stage)")
                #expect(!message.contains("%"), "\(step.technique): \(message)")
            }
            game.apply(step)
        }
        #expect(seen.contains { $0.level == 3 })
    }

    @Test func wingNudgePointsAtThePivot() {
        let step = SolveStep(
            technique: .xyWing,
            eliminations: [Elimination(cell: 1, digits: [3])],
            patternCells: [0, 4, 18],
            patternDigits: [1, 2, 3]
        )
        let nudge = HintHighlights(hint: .step(step, board: Board()), stage: .nudge)
        #expect(nudge.style(for: 0)?.isFocus == true)
        #expect(nudge.style(for: 4) == nil)
    }

    // MARK: Highlights

    @Test func highlightsGrowWithEachStage() throws {
        let board = Board()
        let step = SolveStep(
            technique: .pointing,
            eliminations: [Elimination(cell: 3, digits: [5])],
            focusHouses: [House(kind: .box, index: 0), House(kind: .row, index: 0)],
            patternCells: [0, 1],
            patternDigits: [5]
        )
        let hint = Hint.step(step, board: board)

        let nudge = HintHighlights(hint: hint, stage: .nudge)
        #expect(nudge.style(for: 9)?.isFocus == true)  // in box 0
        #expect(nudge.style(for: 3) == nil)            // row 0 only shown later
        #expect(nudge.style(for: 0)?.isPattern == false)

        let explanation = HintHighlights(hint: hint, stage: .explanation)
        #expect(explanation.style(for: 3)?.isFocus == true)
        #expect(explanation.style(for: 0)?.isPattern == true)
        #expect(explanation.style(for: 0)?.emphasizedNotes == [5])
        #expect(explanation.style(for: 3)?.eliminatedNotes.isEmpty == true)

        let result = HintHighlights(hint: hint, stage: .result)
        #expect(result.style(for: 3)?.eliminatedNotes == [5])
    }

    @Test func placementsAreOnlyPreviewedInTheResultStage() {
        let step = SolveStep(
            technique: .hiddenSingle,
            placements: [Placement(cell: 0, digit: 5)],
            focusHouses: [House(kind: .row, index: 0)],
            patternCells: [0],
            patternDigits: [5]
        )
        let hint = Hint.step(step, board: Board())
        #expect(HintHighlights(hint: hint, stage: .explanation).style(for: 0)?.ghostDigit == nil)
        #expect(HintHighlights(hint: hint, stage: .explanation).style(for: 0)?.emphasizedNotes.isEmpty == true)
        #expect(HintHighlights(hint: hint, stage: .result).style(for: 0)?.ghostDigit == 5)
    }
}
