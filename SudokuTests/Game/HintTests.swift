//
//  HintTests.swift
//  SudokuTests
//

import Foundation
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
            let steps = HintFinder.hint(for: game).steps
            guard !steps.isEmpty else { break }
            for step in steps {
                game.apply(step)
            }
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
        // Without notes every hint ends in a placement, so there is exactly one hint per empty cell.
        #expect(hints == game.puzzle.givens.count { $0 == 0 })
    }

    @Test func applyingHintsSolvesThePuzzleWithFullNotes() {
        var game = generatedGame(.medium, seed: 4)
        game.fillNotes()
        _ = solveWithHints(&game)
        #expect(game.isSolved)
        #expect(game.mistakeCount == 0)
    }

    /// Without notes, an elimination is useless on its own: the hint follows it to the placement it
    /// enables, and applying the hint remembers the eliminations.
    @Test(arguments: [(Difficulty.medium, UInt64(1)), (.hard, 1), (.expert, 3), (.master, 1)])
    func withoutNotesHintsChainEliminationsIntoAPlacement(difficulty: Difficulty, seed: UInt64) throws {
        var game = generatedGame(difficulty, seed: seed)
        // Play until the first hint that needs an elimination.
        var hint = HintFinder.hint(for: game)
        while case .step(let step, _) = hint, !step.placements.isEmpty {
            game.apply(step)
            hint = HintFinder.hint(for: game)
        }
        guard case .chain(let links) = hint else {
            Issue.record("Expected a chained hint, got \(hint)")
            return
        }
        let placement = try #require(links.last?.step.placements.first)
        #expect(game.puzzle.solution[placement.cell] == placement.digit)
        for link in links.dropLast() {
            #expect(link.step.placements.isEmpty)
            #expect(!link.step.eliminations.isEmpty)
            for elimination in link.step.eliminations {
                #expect(!elimination.digits.contains(game.puzzle.solution[elimination.cell]))
            }
        }

        // The walkthrough explains every link and names each page's technique.
        let pages = HintWalkthrough.pages(for: hint)
        #expect(pages.first?.kind == .nudge)
        #expect(pages.last?.kind == .result)
        #expect(pages.allSatisfy { $0.technique != nil })
        #expect(Set(pages.compactMap(\.technique)) == Set(links.map(\.step.technique)))

        for step in hint.steps {
            game.apply(step)
        }
        #expect(game.values[placement.cell] == placement.digit)
        for link in links.dropLast() {
            for elimination in link.step.eliminations {
                #expect(game.deducedEliminations[elimination.cell].isSuperset(of: elimination.digits))
            }
        }
    }

    @Test func notedEliminationsAreOfferedOnTheirOwn() {
        var game = generatedGame(.medium, seed: 1)
        game.fillNotes()
        var hint = HintFinder.hint(for: game)
        while case .step(let step, _) = hint, !step.placements.isEmpty {
            game.apply(step)
            hint = HintFinder.hint(for: game)
        }
        // The player can remove these notes, so the elimination is the hint.
        guard case .step(let step, _) = hint else {
            Issue.record("Expected a plain elimination step, got \(hint)")
            return
        }
        #expect(step.placements.isEmpty)
    }

    @Test func autoSolveSeesEveryStepOnItsOwn() {
        var game = generatedGame(.medium, seed: 1)
        var hint = HintFinder.hint(for: game, chainsEliminations: false)
        while case .step(let step, _) = hint, !step.placements.isEmpty {
            game.apply(step)
            hint = HintFinder.hint(for: game, chainsEliminations: false)
        }
        guard case .step(let step, _) = hint else {
            Issue.record("Expected a plain step")
            return
        }
        #expect(step.placements.isEmpty)
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

    // MARK: Note problems

    @Test func impossibleNotesComeBeforeLogic() throws {
        var game = try easyGame()
        // Cell 2 (row 1) can't be 5: the 5 at r1c1 is in the same row and box.
        game.toggleNote(5, at: 2)
        game.toggleNote(4, at: 2)
        guard case .impossibleNotes(let notes, let blockers) = HintFinder.hint(for: game) else {
            Issue.record("Expected impossible notes")
            return
        }
        #expect(notes == [Elimination(cell: 2, digits: [5])])
        #expect(blockers.allSatisfy { game.values[$0] == 5 && Geometry.sees($0, 2) })

        game.removeNotes(notes)
        #expect(game.notes[2] == [4])
        #expect(HintFinder.impossibleNotes(in: game).isEmpty)
    }

    @Test func notesMissingTheSolutionAreFlaggedAndRefilled() throws {
        var game = try easyGame()
        // Cell 2's solution is 4; noting only 1 and 2 leaves it out.
        game.toggleNote(1, at: 2)
        game.toggleNote(2, at: 2)
        #expect(HintFinder.hint(for: game) == .notesMissingSolution([2]))

        game.refillNotes(in: [2])
        #expect(game.notes[2] == Board(values: game.values).candidates(at: 2))
        #expect(game.notes[2].contains(4))
        // Fixed: back to logic.
        guard case .step = HintFinder.hint(for: game) else {
            Issue.record("Expected a step after fixing the notes")
            return
        }
        game.undo()
        #expect(game.notes[2] == [1, 2])
    }

    @Test func wrongDigitsComeBeforeNoteProblems() throws {
        var game = try easyGame()
        game.toggleNote(5, at: 3)
        game.enter(1, at: 2) // wrong
        #expect(HintFinder.hint(for: game) == .incorrectEntries([2]))
    }

    @MainActor
    @Test func modelFixesTheNotesTheHintPointsOut() throws {
        var game = try easyGame()
        game.toggleNote(5, at: 2)
        let model = GameModel(game: game, settings: AppSettings(defaults: try #require(UserDefaults(suiteName: "HintTests.\(UUID().uuidString)"))))
        model.requestHint()
        #expect(HintWalkthrough.pages(for: try #require(model.activeHint?.hint)).first?.highlights.style(for: 2)?.marks[5] == .eliminated)
        model.fixNotes()
        #expect(model.game.notes[2].isEmpty)
        #expect(model.activeHint == nil)
    }

    // MARK: Detailed explanation

    @Test func everyTechniqueHasAGuide() {
        for technique in TechniqueKind.allCases {
            let guide = technique.guide
            #expect(!guide.howItWorks.isEmpty && !guide.howToSpot.isEmpty, "\(technique)")
            #expect(!guide.howItWorks.contains("%"), "\(technique)")
        }
    }

    @MainActor
    @Test func detailedModeShowsAndAddsTheCandidatesAroundTheHint() throws {
        let model = GameModel(game: generatedGame(.medium, seed: 1), settings: AppSettings(defaults: try #require(UserDefaults(suiteName: "HintTests.\(UUID().uuidString)"))))
        model.requestHint()
        let cells = model.hintCells
        #expect(!cells.isEmpty)
        let cell = try #require(cells.first)
        #expect(model.hintHighlights.style(for: cell)?.marks.values.contains(.context) != true)

        model.setShowsHintCandidates(true)
        let board = HintFinder.candidateBoard(for: model.game)
        let shown = try #require(model.hintHighlights.style(for: cell)).markedDigits
        #expect(shown.isSuperset(of: board.candidates(at: cell)))

        #expect(model.canAddHintCandidatesToNotes)
        model.addHintCandidatesToNotes()
        for cell in cells {
            #expect(model.game.notes[cell] == board.candidates(at: cell))
        }
        #expect(!model.canAddHintCandidatesToNotes)
        // Cells outside the hint keep their (empty) notes.
        let outside = try #require(Geometry.cells.first { model.game.values[$0] == 0 && !cells.contains($0) })
        #expect(model.game.notes[outside].isEmpty)

        model.closeHint()
        #expect(!model.showsHintCandidates)
    }

    // MARK: Walkthrough

    /// Every hint of a hard puzzle starts with a nudge, ends with the result, and has wording on
    /// every page with all placeholders filled in.
    @Test(arguments: [(Difficulty.hard, UInt64(1)), (.hard, 2), (.hard, 3), (.expert, 3), (.expert, 12), (.master, 1), (.master, 2)])
    func everyStepOfAHardPuzzleHasAWalkthrough(difficulty: Difficulty, seed: UInt64) {
        var seen = Set<TechniqueKind>()
        // Auto solve's view of the hints, so elimination steps get their own walkthrough too.
        for chains in [false, true] {
            var game = generatedGame(difficulty, seed: seed)
            while !game.isFinished {
                let hint = HintFinder.hint(for: game, chainsEliminations: chains)
                guard !hint.steps.isEmpty else { break }
                let pages = HintWalkthrough.pages(for: hint)
                let name = hint.mainTechnique.map(\.rawValue) ?? "?"
                seen.formUnion(hint.steps.map(\.technique))
                #expect(pages.count >= 3, "\(name) has no explanation")
                #expect(pages.first?.kind == .nudge)
                #expect(pages.last?.kind == .result)
                for page in pages {
                    #expect(!page.text.isEmpty, "\(name) has an empty page")
                    #expect(!page.text.contains("%"), "\(name): \(page.text)")
                }
                for step in hint.steps {
                    game.apply(step)
                }
            }
            #expect(game.isSolved)
        }
        #expect(seen.contains { $0.level == difficulty.level })
    }

    @Test func wingNudgePointsAtThePivot() {
        let step = SolveStep(
            technique: .xyWing,
            eliminations: [Elimination(cell: 1, digits: [3])],
            patternCells: [0, 4, 18],
            patternDigits: [1, 2, 3]
        )
        let nudge = HintWalkthrough.pages(for: .step(step, board: Board()))[0].highlights
        #expect(nudge.style(for: 0)?.fill == .pattern)
        #expect(nudge.style(for: 4) == nil)
    }

    @Test func pointingBuildsUpPageByPage() {
        let step = SolveStep(
            technique: .pointing,
            eliminations: [Elimination(cell: 3, digits: [5])],
            focusHouses: [House(kind: .box, index: 0), House(kind: .row, index: 0)],
            patternCells: [0, 1],
            patternDigits: [5]
        )
        let pages = HintWalkthrough.pages(for: .step(step, board: Board()))
        #expect(pages.map(\.kind) == [.nudge, .explanation, .explanation, .result])

        let nudge = pages[0].highlights
        #expect(nudge.style(for: 9)?.fill == .house)  // in box 0
        #expect(nudge.style(for: 3) == nil)           // row 0 only shown later
        #expect(nudge.style(for: 0)?.fill == .house)

        let box = pages[1].highlights
        #expect(box.style(for: 0)?.fill == .pattern)
        #expect(box.style(for: 0)?.marks == [5: .emphasized])
        #expect(box.style(for: 3) == nil)

        let line = pages[2].highlights
        #expect(line.style(for: 3)?.fill == .house)
        #expect(line.style(for: 3)?.marks.isEmpty == true)

        let result = pages[3].highlights
        #expect(result.style(for: 3)?.fill == .target)
        #expect(result.style(for: 3)?.marks == [5: .eliminated])
    }

    @Test func hiddenSingleShowsTheDigitsThatRuleOutTheOtherCells() throws {
        // Row 0 is empty. The 5s at r2c4, r3c7, r5c2 and r8c3 see every cell of row 0 except r1c1.
        var values = Array(repeating: 0, count: Geometry.cellCount)
        let blockers = [Geometry.cell(row: 1, column: 3), Geometry.cell(row: 2, column: 6), Geometry.cell(row: 4, column: 1), Geometry.cell(row: 7, column: 2)]
        for cell in blockers {
            values[cell] = 5
        }
        let step = SolveStep(
            technique: .hiddenSingle,
            placements: [Placement(cell: 0, digit: 5)],
            focusHouses: [House(kind: .row, index: 0)],
            patternCells: [0],
            patternDigits: [5]
        )
        let pages = HintWalkthrough.pages(for: .step(step, board: Board(values: values)))
        let explanation = try #require(pages.first { $0.kind == .explanation }).highlights
        #expect(Set(blockers.filter { explanation.style(for: $0)?.fill == .blocker }) == Set(blockers))
        #expect(explanation.style(for: 0)?.fill == .pattern)
        // The answer is only previewed on the result page.
        #expect(explanation.style(for: 0)?.ghostDigit == nil)
        #expect(pages.last?.highlights.style(for: 0)?.ghostDigit == 5)
    }

    @Test func xWingColorsItsTwoDiagonals() throws {
        var board = Board()
        for column in 0..<9 where column != 2 && column != 6 {
            board.eliminate([5], from: Geometry.cell(row: 1, column: column))
            board.eliminate([5], from: Geometry.cell(row: 4, column: column))
        }
        let step = try #require(BasicFish.xWing.findStep(in: board))
        let pages = HintWalkthrough.pages(for: .step(step, board: board))
        let diagonals = try #require(pages.last { $0.kind == .explanation }).highlights
        let mark = { (row: Int, column: Int) in diagonals.style(for: Geometry.cell(row: row, column: column))?.marks[5] }
        #expect(mark(1, 2) == .alternativeA)
        #expect(mark(4, 6) == .alternativeA)
        #expect(mark(1, 6) == .alternativeB)
        #expect(mark(4, 2) == .alternativeB)
        let strongLinks = diagonals.links.filter { $0.isStrong }
        #expect(diagonals.links.count == 2)
        #expect(strongLinks.count == 2)
    }

    @MainActor
    @Test func modelStepsBackAndForthThroughPages() throws {
        let model = GameModel(game: generatedGame(.medium, seed: 1), settings: AppSettings(defaults: UserDefaults(suiteName: "HintTests.\(UUID().uuidString)") ?? .standard))
        model.requestHint()
        let hint = try #require(model.activeHint)
        #expect(hint.pageIndex == 0)
        #expect(!hint.canGoBack)

        model.showPreviousHintPage()
        #expect(model.activeHint?.pageIndex == 0)

        for _ in 0..<20 {
            model.showNextHintPage()
        }
        #expect(model.activeHint?.pageIndex == hint.pages.count - 1)
        #expect(model.activeHint?.canGoForward == false)
        #expect(model.hintHighlights == hint.pages.last?.highlights)

        model.showPreviousHintPage()
        #expect(model.activeHint?.pageIndex == hint.pages.count - 2)
        #expect(model.hintHighlights == hint.pages[hint.pages.count - 2].highlights)
    }
}
