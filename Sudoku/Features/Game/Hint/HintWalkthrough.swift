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
        /// How to find the technique: its search space on this board.
        case spotting
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
    /// The technique this page explains; changes from page to page in a chained hint.
    var technique: TechniqueKind?
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

        case .impossibleNotes(let eliminations, let blockers):
            var highlights = HintHighlights()
            for elimination in eliminations {
                highlights.fill([elimination.cell], .target)
                highlights.mark(elimination.digits, in: elimination.cell, as: .eliminated)
            }
            highlights.fill(blockers, .blocker)
            let text = String(localized: "Some notes can't be right: each crossed-out digit is already placed in the same row, column or box (highlighted).")
            return [HintPage(kind: .message, text: text, highlights: highlights)]

        case .notesMissingSolution(let cells):
            var highlights = HintHighlights()
            highlights.fill(cells, .incorrect)
            let text = String(localized: "The notes in the highlighted cells leave out a digit that can still go there, so hints can't build on them. Fixing them refills those cells with every digit still possible.")
            return [HintPage(kind: .message, text: text, highlights: highlights)]

        case .notesIncomplete(let cells):
            // In the light color of a house, not a target's: nothing is wrong in these cells.
            var highlights = HintHighlights()
            highlights.fill(cells, .house)
            let text = String(localized: "Your notes aren't complete: the highlighted cells have none yet. Solving starts by noting, in every empty cell, each digit its row, column and box still allow.")
            return [HintPage(kind: .message, text: text, highlights: highlights)]

        case .unavailable:
            let text = String(localized: "The next step needs a technique that isn't available yet. You can reveal a cell instead.")
            return [HintPage(kind: .message, text: text, highlights: HintHighlights())]

        case .step(let step, let board):
            var builder = WalkthroughBuilder(step: step, board: board)
            builder.addNudge()
            builder.addSpotting()
            builder.addExplanation()
            builder.addResult()
            return builder.pages

        case .chain(let links):
            // Each elimination is explained and ends with what it rules out; the last link places
            // the digit those eliminations made possible.
            var pages: [HintPage] = []
            for (index, link) in links.enumerated() {
                var builder = WalkthroughBuilder(step: link.step, board: link.board)
                if index == 0 {
                    builder.addNudge()
                }
                builder.addSpotting()
                builder.addExplanation()
                if index == links.count - 1 {
                    builder.addResult(endsWithoutPlacement: link.step.placements.isEmpty)
                } else {
                    builder.addConsequence()
                }
                pages += builder.pages
            }
            return pages
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
        pages.append(HintPage(kind: .nudge, text: text, highlights: nudge, technique: step.technique))
    }

    /// Where the player should have been looking: the technique's search space on this board.
    mutating func addSpotting() {
        let text = String(localized: "How to spot it: \(step.technique.guide.howToSpot)")
        pages.append(HintPage(kind: .spotting, text: text, highlights: HintSpotting.highlights(for: step, board: board), technique: step.technique))
    }

    mutating func addResult(endsWithoutPlacement: Bool = false) {
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
        } else if endsWithoutPlacement {
            String(localized: "So \(HintText.digitList(removedDigits)) can't go in the cells marked in red. No digit can be placed from this alone yet; apply it and the next hint continues from here.")
        } else {
            String(localized: "Remove \(HintText.digitList(removedDigits)) from the highlighted cells.")
        }
        add(text, kind: .result)
    }

    /// Ends an elimination that leads on to a later step: shows what it rules out without applying it.
    mutating func addConsequence() {
        for elimination in step.eliminations {
            highlights.fill([elimination.cell], .target)
            highlights.mark(elimination.digits, in: elimination.cell, as: .eliminated)
        }
        add(String(localized: "So \(HintText.digitList(removedDigits)) can't go in the cells marked in red."))
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
        case .swordfish, .jellyfish: largeFish()
        case .finnedXWing, .finnedSwordfish: finnedFish()
        case .emptyRectangle: emptyRectangle()
        case .simpleColoring: simpleColoring()
        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4: uniqueRectangle()
        case .bug: bug()
        case .remotePair: remotePair()
        case .xChain, .xyChain, .aic: alternatingChain()
        case .alsXZ: alsXZ()
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
        pages.append(HintPage(kind: kind, text: text, highlights: highlights, technique: step.technique))
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

    // MARK: Fish

    /// Swordfish and Jellyfish: houses are `[base lines…, cover lines…]`.
    private mutating func largeFish() {
        let size = step.focusHouses.count / 2
        let bases = Array(step.focusHouses.prefix(size))
        let covers = Array(step.focusHouses.suffix(size))

        highlights.fill(bases)
        showPattern(step.patternCells)
        add(String(localized: "In \(HintText.houseList(bases)), \(digit) fits only in cells that lie in \(HintText.houseList(covers))."))

        highlights.fill(covers)
        add(String(localized: "Each of these \(size) lines needs a \(digit), each in a different one of \(HintText.houseList(covers)). So those lines get their \(digit) here, and it can be removed from the rest of them."))
    }

    /// Finned X-Wing and Swordfish: houses are `[base lines…, cover lines…, fin box]`.
    private mutating func finnedFish() {
        let size = (step.focusHouses.count - 1) / 2
        let bases = Array(step.focusHouses.prefix(size))
        let covers = Array(step.focusHouses.dropFirst(size).prefix(size))
        let box = house(step.focusHouses.count - 1)
        let fins = step.patternCells.filter { cell in !covers.contains { $0.contains(cell) } }
        let fishName = size == 2 ? TechniqueKind.xWing.title : TechniqueKind.swordfish.title

        highlights.fill(bases)
        showPattern(step.patternCells.filter { !fins.contains($0) })
        highlights.fill(fins, .pattern)
        for fin in fins {
            highlights.mark([digit], in: fin, as: .alternativeB)
        }
        add(String(localized: "In \(HintText.houseList(bases)), \(digit) fits only in \(HintText.houseList(covers)), except for the fin in \(name(box))."))

        highlights.fill(covers)
        highlights.fill([box])
        add(String(localized: "If the fin isn't \(digit), this is an ordinary \(fishName) and \(digit) leaves the rest of \(HintText.houseList(covers)). If the fin is \(digit), \(digit) leaves the cells of \(name(box)) that it sees. Cells hit both ways can't be \(digit)."))
    }

    // MARK: Level 4 patterns

    /// Cells `[x, y, box cells…]`, houses `[box, linkLine, crossedLine, keptLine]`.
    private mutating func emptyRectangle() {
        let (box, link, crossed, kept) = (house(0), house(1), house(2), house(3))
        let (x, y) = (cell(0), cell(1))
        let boxCells = Array(step.patternCells.dropFirst(2))
        let target = step.eliminations.first?.cell ?? y

        highlights.fill([box])
        showPattern(boxCells)
        add(String(localized: "In \(name(box)), every \(digit) lies on \(name(crossed)) or \(name(kept))."))

        highlights.fill([link])
        showPattern([x, y])
        highlights.link(x, y, digit: digit, isStrong: true)
        add(String(localized: "In \(name(link)), \(digit) fits in only two cells."))

        // Blue: x holds the digit, pushing the box's digit onto the kept line. Green: y holds it.
        highlights.fill([kept])
        highlights.mark([digit], in: x, as: .alternativeB)
        for cell in boxCells where kept.contains(cell) {
            highlights.mark([digit], in: cell, as: .alternativeB)
        }
        highlights.mark([digit], in: y, as: .alternativeA)
        add(String(localized: "If the cell at \(name(x)) is \(digit), the \(digit) in \(name(box)) can't be on \(name(crossed)), so it is on \(name(kept)). If not, the cell at \(name(y)) is \(digit). Either way the cell at \(name(target)) can't be \(digit)."))
    }

    private mutating func simpleColoring() {
        let chain = SimpleColoring.chain(of: digit, startingAt: cell(0), in: board)
        highlights.fill(chain.cells.map(\.cell), .pattern)
        for (cell, isColorA) in chain.cells {
            highlights.mark([digit], in: cell, as: isColorA ? .alternativeA : .alternativeB)
        }
        for (from, to) in chain.links {
            highlights.link(from, to, digit: digit, isStrong: true)
        }
        add(String(localized: "Follow the strong links of \(digit): in each linked house it fits in only two cells, so exactly one of them is \(digit). Coloring the cells alternately gives two groups, and exactly one group holds \(digit)."))

        let eliminated = step.eliminations.map(\.cell)
        if eliminated.allSatisfy(chain.cells.map(\.cell).contains) {
            // Color wrap: show the two cells of the same color that see each other.
            if let pair = eliminated.combinations(ofSize: 2).first(where: { Geometry.sees($0[0], $0[1]) }) {
                highlights.link(pair[0], pair[1], digit: digit, isStrong: false)
            }
            add(String(localized: "Two cells of the same color see each other, so that color can't hold \(digit). \(digit) can be removed from all its cells."))
        } else {
            highlights.fill(eliminated, .target)
            add(String(localized: "Some cells outside the chain see a cell of each color. Whichever color holds \(digit), they see it, so they can't be \(digit)."))
        }
    }

    /// Type 1 cells `[corner, corner, corner, target]`; types 2 and 4 `[floor1, floor2, roof1, roof2]`.
    private mutating func uniqueRectangle() {
        let corners = Array(step.patternCells.prefix(4))
        let a = step.patternDigits.min() ?? 0
        let b = step.patternDigits.max() ?? 0
        showPattern(corners)
        add(String(localized: "The four highlighted cells form a rectangle across two rows, two columns and two boxes, and each of them can be \(a) or \(b)."))

        switch step.technique {
        case .uniqueRectangleType1:
            let target = cell(3)
            highlights.fill([target], .target)
            add(String(localized: "If the cell at \(name(target)) were also only \(a) or \(b), the two digits could be swapped in all four cells and the puzzle would have two solutions. So \(a) and \(b) can be removed from it."))

        case .uniqueRectangleType2:
            let x = removedDigits.min() ?? 0
            for roof in corners.suffix(2) {
                highlights.mark([x], in: roof, as: .alternativeA)
            }
            add(String(localized: "The other two corners can also be \(x). If neither of them were \(x), the two digits could be swapped and the puzzle would have two solutions. So one of them is \(x), and a cell that sees both can't be \(x)."))

        default:
            let weak = removedDigits.min() ?? 0
            let strong = step.patternDigits.subtracting([weak]).min() ?? 0
            let house = house(0)
            highlights.fill([house])
            highlights.link(cell(2), cell(3), digit: strong, isStrong: true)
            add(String(localized: "In \(name(house)), \(strong) fits only in the two other corners, so one of them is \(strong). If the other were \(weak), the two digits could be swapped and the puzzle would have two solutions. So neither of them can be \(weak)."))
        }
    }

    private mutating func bug() {
        let target = cell(0)
        let house = house(0)
        highlights.fill(board.emptyCells.filter { $0 != target }, .house)
        highlights.fill([target], .pattern)
        add(String(localized: "Every empty cell has exactly two candidates except the cell at \(name(target)), which has three."))

        highlights.fill([house])
        for cell in board.cells(in: house, withCandidate: digit) {
            highlights.mark([digit], in: cell, as: .emphasized)
        }
        add(String(localized: "If that cell weren't \(digit), every candidate would appear exactly twice in each house and the puzzle would have two solutions. \(digit) appears three times in \(name(house)), so the cell must be \(digit)."))
    }

    // MARK: Chains

    /// X-Chain, XY-Chain and AIC. `step.chain` alternates strong and weak links, starting and ending
    /// with a strong one.
    private mutating func alternatingChain() {
        let nodes = step.chain
        guard let start = nodes.first, let end = nodes.last else { return }

        highlights.fill(step.patternCells, .pattern)
        for node in nodes {
            highlights.mark([node.digit], in: node.cell, as: .emphasized)
        }
        for index in nodes.indices.dropLast() {
            highlights.link(nodes[index], nodes[index + 1], isStrong: index % 2 == 0)
        }
        add(String(localized: "These candidates form a chain. Along a solid link at least one of the two is true; along a dashed link at most one is."))

        // Assume the start is false (blue): every second candidate after it is then true (green).
        for (index, node) in nodes.enumerated() {
            highlights.mark([node.digit], in: node.cell, as: index % 2 == 0 ? .alternativeB : .alternativeA)
        }
        add(String(localized: "Suppose \(start.digit) at \(name(start.cell)) is false. Following the links, every second candidate must then be true, up to \(end.digit) at \(name(end.cell)). So at least one of the two ends is true."))

        highlights.mark([start.digit], in: start.cell, as: .alternativeA)
        if start.cell == end.cell {
            add(String(localized: "So the cell at \(name(start.cell)) is \(start.digit) or \(end.digit), and its other candidates can be removed."))
        } else if start.digit == end.digit {
            add(String(localized: "So \(start.digit) is at \(name(start.cell)) or at \(name(end.cell)), and a cell that sees both can't be \(start.digit)."))
        } else if step.eliminations.count == 1, let only = step.eliminations.first {
            // Only one of the two cells has the other end's digit.
            let lost = HintText.digitList(only.digits)
            add(String(localized: "So the cell at \(name(start.cell)) is \(start.digit) or the cell at \(name(end.cell)) is \(end.digit). They see each other, so the cell at \(name(only.cell)) can't be \(lost)."))
        } else {
            add(String(localized: "So the cell at \(name(start.cell)) is \(start.digit) or the cell at \(name(end.cell)) is \(end.digit). They see each other, so the first can't be \(end.digit) and the second can't be \(start.digit)."))
        }
    }

    /// Cells are the chain in order; digits are {a, b}.
    private mutating func remotePair() {
        let cells = step.patternCells
        let a = step.patternDigits.min() ?? 0
        let b = step.patternDigits.max() ?? 0

        showPattern(cells)
        for index in cells.indices.dropLast() {
            highlights.link(cells[index], cells[index + 1], digit: a, isStrong: false)
        }
        add(String(localized: "Each highlighted cell can only be \(a) or \(b), and each one sees the next in the chain. So the digits alternate along the chain."))

        for (index, cell) in cells.enumerated() {
            highlights.mark(step.patternDigits, in: cell, as: index % 2 == 0 ? .alternativeA : .alternativeB)
        }
        add(String(localized: "The two ends are an odd number of steps apart, so one of them is \(a) and the other is \(b). A cell that sees both ends can't be either digit."))
    }

    /// Groups are `[A, B]`, houses `[house of A, house of B]`, digits {X, Z} with Z eliminated.
    private mutating func alsXZ() {
        guard step.cellGroups.count == 2, let z = removedDigits.single else { return }
        let (groupA, groupB) = (step.cellGroups[0], step.cellGroups[1])
        let x = step.patternDigits.subtracting([z]).min() ?? 0
        let digitsA = groupA.reduce(CandidateSet()) { $0.union(board.candidates(at: $1)) }
        let digitsB = groupB.reduce(CandidateSet()) { $0.union(board.candidates(at: $1)) }

        highlights.fill([house(0)])
        showPattern(groupA, digits: digitsA)
        add(String(localized: "In \(name(house(0))), the highlighted cells can only hold \(HintText.digitList(digitsA)): one digit more than there are cells. That makes them an almost locked set."))

        highlights.fill([house(1)])
        showPattern(groupB, digits: digitsB)
        add(String(localized: "The highlighted cells in \(name(house(1))) are another one, with \(HintText.digitList(digitsB))."))

        let xA = groupA.filter { board.candidates(at: $0).contains(x) }
        let xB = groupB.filter { board.candidates(at: $0).contains(x) }
        for cell in xA + xB {
            highlights.mark([x], in: cell, as: .alternativeB)
        }
        if let from = xA.first, let to = xB.first {
            highlights.link(from, to, digit: x, isStrong: false)
        }
        add(String(localized: "Every \(x) in one set sees every \(x) in the other, so \(x) is in at most one of them. The set without \(x) has as many digits as cells left, so it must hold all of them, \(z) included."))

        for cell in groupA + groupB where board.candidates(at: cell).contains(z) {
            highlights.mark([z], in: cell, as: .alternativeA)
        }
        add(String(localized: "So \(z) is in at least one of the two sets, and a cell that sees every \(z) in both can't be \(z)."))
    }
}
