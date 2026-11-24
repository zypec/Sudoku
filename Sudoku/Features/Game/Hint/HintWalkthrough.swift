//
//  HintWalkthrough.swift
//  Sudoku
//

import Foundation

/// One screen of a hint: a sentence and what the board highlights while it is shown.
struct HintPage: Equatable {
    enum Kind: Equatable {
        /// The technique's name and where to look.
        case nudge
        /// One step of the reasoning.
        case explanation
        /// The placement or eliminations, ready to apply.
        case result
        /// A hint that isn't a step (wrong entries, nothing found).
        case message
    }

    let kind: Kind
    let text: String
    let highlights: HintHighlights
}

/// Turns a hint into pages the player can step through: the technique and where to look, the
/// reasoning one step at a time, and finally the result. Within the reasoning, highlights build up
/// from page to page, so going back shows exactly what was on screen before.
enum HintWalkthrough {
    static func pages(for hint: Hint) -> [HintPage] {
        switch hint {
        case .incorrectEntries(let cells):
            var highlights = HintHighlights()
            highlights.fill(cells, .incorrect)
            let text = String(localized: "Some digits on the board are incorrect. Fix them before looking for the next step.")
            return [HintPage(kind: .message, text: text, highlights: highlights)]

        case .unavailable:
            let text = String(localized: "The next step needs a technique that isn't available yet. You can reveal a cell instead.")
            return [HintPage(kind: .message, text: text, highlights: HintHighlights())]

        case .step(let step, let board):
            var builder = WalkthroughBuilder(step: step, board: board)
            builder.addNudge()
            builder.addExplanation()
            builder.addResult()
            return builder.pages
        }
    }
}

/// Builds the pages of a step hint. Each technique documents the order of its `focusHouses` and
/// `patternCells`; the explanations below rely on it.
private struct WalkthroughBuilder {
    let step: SolveStep
    let board: Board
    private(set) var pages: [HintPage] = []
    /// Highlights of the page being built; explanation pages add to it.
    private var highlights = HintHighlights()

    init(step: SolveStep, board: Board) {
        self.step = step
        self.board = board
    }

    // MARK: Shared pages

    mutating func addNudge() {
        var nudge = HintHighlights()
        let title = step.technique.title
        let text: String
        if let house = step.focusHouses.first {
            nudge.fill([house])
            text = String(localized: "Look for \(title) in \(HintText.houseName(house)).")
        } else {
            // Wings have no single house; point at their pivot instead.
            let pivot = step.patternCells.first ?? 0
            nudge.fill([pivot], .pattern)
            text = String(localized: "Look for \(title) around the cell at \(HintText.cellName(pivot)).")
        }
        pages.append(HintPage(kind: .nudge, text: text, highlights: nudge))
    }

    mutating func addResult() {
        for elimination in step.eliminations {
            highlights.fill([elimination.cell], .target)
            highlights.mark(elimination.digits, in: elimination.cell, as: .eliminated)
        }
        for placement in step.placements {
            highlights.fill([placement.cell], .target)
            highlights.ghost(placement.digit, in: placement.cell)
        }
        let text = if let placement = step.placements.first {
            String(localized: "Place \(placement.digit) at \(HintText.cellName(placement.cell)).")
        } else {
            String(localized: "Remove \(HintText.digitList(removedDigits)) from the highlighted cells.")
        }
        add(text, kind: .result)
    }

    mutating func addExplanation() {
        switch step.technique {
        case .fullHouse: fullHouse()
        case .hiddenSingle: hiddenSingle()
        case .nakedSingle: nakedSingle()
        case .pointing, .claiming: lockedCandidates()
        case .nakedPair, .nakedTriple, .nakedQuad: nakedSubset()
        case .hiddenPair, .hiddenTriple, .hiddenQuad: hiddenSubset()
        case .xWing: xWing()
        case .skyscraper, .twoStringKite: twoStrongLinks()
        case .xyWing, .xyzWing: wing()
        case .wWing: wWing()
        }
    }

    // MARK: Helpers

    /// The digit single-digit techniques are about.
    private var digit: Digit {
        step.patternDigits.min() ?? 0
    }

    private var removedDigits: CandidateSet {
        step.eliminations.reduce(CandidateSet()) { $0.union($1.digits) }
    }

    private func house(_ index: Int) -> House {
        step.focusHouses[min(index, step.focusHouses.count - 1)]
    }

    private func cell(_ index: Int) -> CellIndex {
        step.patternCells[min(index, step.patternCells.count - 1)]
    }

    private func name(_ house: House) -> String {
        HintText.houseName(house)
    }

    private func name(_ cell: CellIndex) -> String {
        HintText.cellName(cell)
    }

    private mutating func add(_ text: String, kind: HintPage.Kind = .explanation) {
        pages.append(HintPage(kind: kind, text: text, highlights: highlights))
    }

    /// Marks the pattern cells and emphasizes the pattern digits among their candidates.
    private mutating func showPattern(_ cells: [CellIndex], digits: CandidateSet? = nil) {
        highlights.fill(cells, .pattern)
        for cell in cells {
            highlights.mark(board.candidates(at: cell).intersection(digits ?? step.patternDigits), in: cell, as: .emphasized)
        }
    }

    // MARK: Singles

    private mutating func fullHouse() {
        let house = house(0)
        highlights.fill([house])
        highlights.fill([cell(0)], .pattern)
        add(String(localized: "Only one cell is empty in \(name(house)), and \(digit) is the only digit missing there."))
    }

    /// Shows the placed digits that rule out every other cell of the house.
    private mutating func hiddenSingle() {
        let house = house(0)
        let target = cell(0)
        highlights.fill([house])
        highlights.fill([target], .pattern)

        var explainedByDigits = true
        for other in house.cells where other != target && board.value(at: other) == 0 {
            // One placed copy of the digit that sees this cell is enough to explain it.
            if let blocker = Geometry.peers[other].first(where: { board.value(at: $0) == digit }) {
                highlights.fill([blocker], .blocker)
            } else {
                explainedByDigits = false
            }
        }
        if explainedByDigits {
            add(String(localized: "In \(name(house)), every other empty cell already sees a \(digit) (highlighted), so \(digit) fits in only one cell."))
        } else {
            add(String(localized: "In \(name(house)), the other empty cells either see a \(digit) (highlighted) or had \(digit) removed earlier, so \(digit) fits in only one cell."))
        }
    }

    /// Shows every placed digit the cell sees.
    private mutating func nakedSingle() {
        let target = cell(0)
        highlights.fill(Geometry.houses(containing: target))
        highlights.fill([target], .pattern)
        let blockers = Geometry.peers[target].filter { board.value(at: $0) != 0 }
        highlights.fill(blockers, .blocker)

        let seen = CandidateSet(blockers.map { board.value(at: $0) })
        if seen.union([digit]) == .all {
            add(String(localized: "The row, column and box of the cell at \(name(target)) already contain every other digit, so only \(digit) is left."))
        } else {
            add(String(localized: "The digits in the row, column and box of the cell at \(name(target)) (highlighted) and earlier eliminations leave only \(digit)."))
        }
    }

    // MARK: Intersections and subsets

    /// Pointing: houses are `[box, line]`. Claiming: `[line, box]`.
    private mutating func lockedCandidates() {
        let (first, second) = (house(0), house(1))
        highlights.fill([first])
        showPattern(step.patternCells)
        add(String(localized: "In \(name(first)), \(digit) can only go in the highlighted cells."))

        highlights.fill([second])
        add(String(localized: "These cells all lie in \(name(second)). Whichever of them is \(digit), no other cell of \(name(second)) can be \(digit)."))
    }

    private mutating func nakedSubset() {
        let house = house(0)
        highlights.fill([house])
        showPattern(step.patternCells)
        let digits = HintText.digitList(step.patternDigits)
        add(String(localized: "In \(name(house)), the \(step.patternCells.count) highlighted cells can only hold \(digits). These digits must fill those cells, so they can be removed from the rest of \(name(house))."))
    }

    private mutating func hiddenSubset() {
        let house = house(0)
        highlights.fill([house])
        showPattern(step.patternCells)
        let digits = HintText.digitList(step.patternDigits)
        add(String(localized: "In \(name(house)), \(digits) can only go in the \(step.patternCells.count) highlighted cells. Those cells must hold exactly these digits, so their other candidates can be removed."))
    }

    // MARK: Single-digit patterns

    /// Houses are `[base1, base2, cover1, cover2]`.
    private mutating func xWing() {
        let (base1, base2, cover1, cover2) = (house(0), house(1), house(2), house(3))
        let cells1 = step.patternCells.filter { base1.contains($0) }
        let cells2 = step.patternCells.filter { base2.contains($0) }
        guard cells1.count == 2, cells2.count == 2 else { return }

        highlights.fill([base1])
        showPattern(cells1)
        highlights.link(cells1[0], cells1[1], digit: digit, isStrong: true)
        add(String(localized: "In \(name(base1)), \(digit) fits in only two cells."))

        highlights.fill([base2])
        showPattern(cells2)
        highlights.link(cells2[0], cells2[1], digit: digit, isStrong: true)
        add(String(localized: "In \(name(base2)) too, \(digit) fits in only two cells, and they lie in the same lines: \(name(cover1)) and \(name(cover2))."))

        // Each diagonal of the rectangle is one way the digit can be placed.
        highlights.fill([cover1, cover2])
        let coverOfFirst = cover1.contains(cells1[0]) ? cover1 : cover2
        for cell in cells1 + cells2 {
            let isFirstDiagonal = (cell == cells1[0]) || (cells2.contains(cell) && !coverOfFirst.contains(cell))
            highlights.mark([digit], in: cell, as: isFirstDiagonal ? .alternativeA : .alternativeB)
        }
        add(String(localized: "So \(digit) is on one of the two diagonals of the highlighted rectangle. Either way \(name(cover1)) and \(name(cover2)) each get a \(digit) here, so it can be removed from the rest of them."))
    }

    /// Skyscraper: cells `[top1, top2, base1, base2]`, houses `[line1, line2, baseLine]`.
    /// 2-String Kite: cells `[rowEnd, columnEnd, rowBoxCell, columnBoxCell]`, houses `[row, column, box]`.
    /// Both are two strong links whose near ends see each other.
    private mutating func twoStrongLinks() {
        let (end1, end2, near1, near2) = (cell(0), cell(1), cell(2), cell(3))
        let (link1, link2, connection) = (house(0), house(1), house(2))

        highlights.fill([link1, link2])
        showPattern([end1, end2, near1, near2])
        highlights.link(near1, end1, digit: digit, isStrong: true)
        highlights.link(near2, end2, digit: digit, isStrong: true)
        add(String(localized: "In \(name(link1)) and \(name(link2)), \(digit) fits in only two cells each."))

        highlights.fill([connection])
        highlights.link(near1, near2, digit: digit, isStrong: false)
        add(String(localized: "Two of these cells are in \(name(connection)), so they can't both be \(digit)."))

        highlights.mark([digit], in: end1, as: .alternativeA)
        highlights.mark([digit], in: end2, as: .alternativeA)
        add(String(localized: "So at least one of the other two ends, \(name(end1)) or \(name(end2)), is \(digit). A cell that sees both can't be \(digit)."))
    }

    // MARK: Wings

    /// XY-Wing and XYZ-Wing: cells `[pivot, pincer1, pincer2]`, z is the eliminated digit.
    private mutating func wing() {
        guard let z = removedDigits.single else { return }
        let (pivot, pincer1, pincer2) = (cell(0), cell(1), cell(2))
        let pivotDigits = board.candidates(at: pivot)
        let x = board.candidates(at: pincer1).intersection(pivotDigits).subtracting([z]).min() ?? 0
        let y = board.candidates(at: pincer2).intersection(pivotDigits).subtracting([z]).min() ?? 0

        showPattern([pivot], digits: pivotDigits)
        add(String(localized: "The cell at \(name(pivot)) can only be \(HintText.digitList(pivotDigits, type: .or))."))

        // Each case: assume the pivot holds one digit (blue) and follow it to z in a pincer (green).
        for (assumed, pincer) in [(x, pincer1), (y, pincer2)] {
            highlights.mark(pivotDigits, in: pivot, as: .emphasized)
            highlights.mark([assumed], in: pivot, as: .alternativeB)
            showPattern([pincer], digits: board.candidates(at: pincer))
            highlights.mark([z], in: pincer, as: .alternativeA)
            highlights.link(pivot, pincer, digit: assumed, isStrong: false)
            add(String(localized: "If it is \(assumed), the cell at \(name(pincer)) can't be \(assumed), so it must be \(z)."))
            highlights.mark([z], in: pincer, as: .emphasized)
        }

        highlights.mark(pivotDigits, in: pivot, as: .emphasized)
        highlights.mark([z], in: pincer1, as: .alternativeA)
        highlights.mark([z], in: pincer2, as: .alternativeA)
        if step.technique == .xyWing {
            add(String(localized: "Either way one of these two cells is \(z), so a cell that sees both can't be \(z)."))
        } else {
            highlights.mark([z], in: pivot, as: .alternativeA)
            add(String(localized: "If it is \(z), then it holds \(z) itself. Either way one of the three cells is \(z), so a cell that sees all three can't be \(z)."))
        }
    }

    /// Cells `[cell1, cell2, link1, link2]`, houses `[linkHouse]`; y is the eliminated digit.
    private mutating func wWing() {
        guard let y = removedDigits.single else { return }
        let (cell1, cell2, link1, link2) = (cell(0), cell(1), cell(2), cell(3))
        let x = step.patternDigits.subtracting([y]).min() ?? 0

        showPattern([cell1, cell2])
        add(String(localized: "The cells at \(name(cell1)) and \(name(cell2)) can only be \(x) or \(y)."))

        let linkHouse = house(0)
        highlights.fill([linkHouse])
        showPattern([link1, link2], digits: [x])
        highlights.link(link1, link2, digit: x, isStrong: true)
        highlights.link(link1, cell1, digit: x, isStrong: false)
        highlights.link(link2, cell2, digit: x, isStrong: false)
        add(String(localized: "In \(name(linkHouse)), \(x) fits in only two cells, and each of them sees one of these cells."))

        highlights.mark([y], in: cell1, as: .alternativeA)
        highlights.mark([y], in: cell2, as: .alternativeA)
        add(String(localized: "Whichever of them is \(x), the cell it sees can't be \(x) and must be \(y). So one of the two cells is \(y), and a cell that sees both can't be \(y)."))
    }
}
