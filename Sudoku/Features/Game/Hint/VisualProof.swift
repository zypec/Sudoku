//
//  VisualProof.swift
//  Sudoku
//

import Foundation

/// Turns a hint into an animated proof on the board: frames that try every case of the technique
/// one assumption at a time. A digit assumed to be in a cell appears there in green, a candidate
/// ruled out is struck in red, and dashed or solid lines show which link caused it. Each case
/// ends by showing what it rules out; the last frame shows that every case rules out the same
/// candidates. Meant for players who don't know the technique: the reasoning is seen, not read.
enum VisualProof {
    static func frames(for hint: Hint) -> [HintPage] {
        switch hint {
        case .step(let step, let board):
            var builder = ProofBuilder(step: step, board: board)
            builder.build()
            return builder.frames
        case .chain(let links):
            return links.flatMap { link in
                var builder = ProofBuilder(step: link.step, board: link.board)
                builder.build()
                return builder.frames
            }
        case .incorrectEntries, .impossibleNotes, .notesMissingSolution, .unavailable:
            return HintWalkthrough.pages(for: hint)
        }
    }
}

/// One candidate in a case, and what the case says about it.
private struct ProofNode {
    enum State {
        /// The digit is in this cell.
        case on
        /// The digit isn't in this cell.
        case off
        /// The digit is in one of the cells marked this way (e.g. somewhere on a line of a box).
        case somewhere
    }

    let node: ChainNode
    let state: State
    /// The candidate whose state forced this one, and whether that link is strong.
    var cause: (node: ChainNode, isStrong: Bool)?
}

/// One frame's worth of a case: a few candidates and the sentence that explains them.
private struct ProofBeat {
    var nodes: [ProofNode]
    /// `nil` builds the standard sentence from the first node.
    var caption: String?
}

/// One way the pattern can resolve.
private struct ProofCase {
    var beats: [ProofBeat]
    /// Set when the case leads to a contradiction instead of eliminations (color wrap).
    var contradiction: String?
}

private struct ProofBuilder {
    let step: SolveStep
    let board: Board
    private(set) var frames: [HintPage] = []

    init(step: SolveStep, board: Board) {
        self.step = step
        self.board = board
    }

    // MARK: Shared pieces

    private var digit: Digit {
        step.patternDigits.min() ?? 0
    }

    private var removedDigits: CandidateSet {
        step.eliminations.reduce(CandidateSet()) { $0.union($1.digits) }
    }

    private func cell(_ index: Int) -> CellIndex {
        step.patternCells[min(index, step.patternCells.count - 1)]
    }

    private func house(_ index: Int) -> House {
        step.focusHouses[min(index, step.focusHouses.count - 1)]
    }

    private func name(_ cell: CellIndex) -> String {
        HintText.cellName(cell)
    }

    private func node(_ cell: CellIndex, _ digit: Digit) -> ChainNode {
        ChainNode(cell: cell, digit: digit)
    }

    /// Every candidate around the step, the houses and the pattern: the board every frame starts from.
    private var base: HintHighlights {
        var highlights = HintHighlights()
        highlights.fill(step.focusHouses)
        var cells = Set(step.focusHouses.flatMap(\.cells))
        cells.formUnion(step.patternCells)
        cells.formUnion(step.chain.map(\.cell))
        cells.formUnion(step.eliminations.map(\.cell))
        cells.formUnion(step.placements.map(\.cell))
        highlights.fill(step.patternCells, .pattern)
        for cell in cells where board.value(at: cell) == 0 {
            highlights.showCandidates(board.candidates(at: cell), in: cell)
        }
        return highlights
    }

    private mutating func add(_ text: String, _ highlights: HintHighlights, kind: HintPage.Kind = .explanation) {
        frames.append(HintPage(kind: kind, text: text, highlights: highlights, technique: step.technique))
    }

    /// Opening frame: the technique's own description of the pattern.
    private mutating func addIntroduction() {
        let pages = HintWalkthrough.pages(for: .step(step, board: board))
        let text = pages.first { $0.kind == .explanation }?.text ?? ""
        add(text, base)
    }

    // MARK: Building

    mutating func build() {
        addIntroduction()
        switch step.technique {
        case .fullHouse, .hiddenSingle, .nakedSingle:
            singles()
        case .bug:
            bug()
        case .hiddenPair, .hiddenTriple, .hiddenQuad:
            hiddenSubset()
        case .swordfish, .jellyfish:
            largeFish()
        case .uniqueRectangleType1, .uniqueRectangleType2, .uniqueRectangleType4:
            uniqueRectangle()
        default:
            play(cases())
        }
    }

    /// The cases of techniques that work by trying each possibility.
    private func cases() -> [ProofCase] {
        switch step.technique {
        case .pointing, .claiming:
            // Whichever pattern cell holds the digit, it sees the targets.
            return step.patternCells.map { ProofCase(beats: [ProofBeat(nodes: [ProofNode(node: node($0, digit), state: .on)])]) }
        case .nakedPair, .nakedTriple, .nakedQuad:
            return nakedSubsetCases()
        case .xWing:
            return xWingCases()
        case .skyscraper, .twoStringKite:
            // Cells are [end1, end2, near1, near2]: end1, or else end1 off, near1 on, near2 off, end2 on.
            let (end1, end2, near1, near2) = (cell(0), cell(1), cell(2), cell(3))
            return [
                single(node(end1, digit), .on),
                propagate([node(end1, digit), node(near1, digit), node(near2, digit), node(end2, digit)], startOn: false, strongFirst: true),
            ]
        case .xyWing, .xyzWing:
            return wingCases()
        case .wWing:
            return wWingCases()
        case .remotePair:
            return remotePairCases()
        case .xChain, .xyChain, .aic:
            // The start is on, or it's off and the chain forces the end on.
            guard let start = step.chain.first else { return [] }
            return [single(start, .on), propagate(step.chain, startOn: false, strongFirst: true)]
        case .emptyRectangle:
            return emptyRectangleCases()
        case .simpleColoring:
            return coloringCases()
        case .finnedXWing, .finnedSwordfish:
            return finnedFishCases()
        case .alsXZ:
            return alsCases()
        default:
            return []
        }
    }

    private func single(_ node: ChainNode, _ state: ProofNode.State) -> ProofCase {
        ProofCase(beats: [ProofBeat(nodes: [ProofNode(node: node, state: state)])])
    }

    /// A chain of alternating links played one candidate at a time, starting with `nodes[0]` on or off.
    private func propagate(_ nodes: [ChainNode], startOn: Bool, strongFirst: Bool) -> ProofCase {
        var beats: [ProofBeat] = []
        var isOn = startOn
        for (index, current) in nodes.enumerated() {
            var proofNode = ProofNode(node: current, state: isOn ? .on : .off)
            if index > 0 {
                // Strong links turn off into on; weak links turn on into off.
                let isStrong = (index % 2 == 1) == strongFirst
                proofNode.cause = (nodes[index - 1], isStrong)
            }
            beats.append(ProofBeat(nodes: [proofNode]))
            isOn.toggle()
        }
        return ProofCase(beats: beats)
    }

    private func nakedSubsetCases() -> [ProofCase] {
        // Every way the subset's cells can hold its digits; shown one by one when there are few.
        let cells = step.patternCells
        var assignments: [[Digit]] = []
        func assign(_ index: Int, _ used: CandidateSet, _ current: [Digit]) {
            guard assignments.count <= 4 else { return }
            if index == cells.count {
                assignments.append(current)
                return
            }
            for digit in board.candidates(at: cells[index]).intersection(step.patternDigits) where !used.contains(digit) {
                assign(index + 1, used.union([digit]), current + [digit])
            }
        }
        assign(0, [], [])
        guard assignments.count <= 4 else { return [] }
        return assignments.map { digits in
            ProofCase(beats: [ProofBeat(nodes: zip(cells, digits).map { ProofNode(node: node($0, $1), state: .on) })])
        }
    }

    private func xWingCases() -> [ProofCase] {
        let base1 = house(0)
        let base2 = house(1)
        let cells1 = step.patternCells.filter { base1.contains($0) }
        let cells2 = step.patternCells.filter { base2.contains($0) }
        guard cells1.count == 2, cells2.count == 2 else { return [] }
        let covers = [house(2), house(3)]
        // The corner of the second line that shares a cover line with `cell`.
        let below = { (cell: CellIndex) -> CellIndex in
            let cover = covers.first { $0.contains(cell) } ?? covers[0]
            return cells2.first { cover.contains($0) } ?? cells2[0]
        }
        return [cells1[0], cells1[1]].map { first in
            let other = first == cells1[0] ? cells1[1] : cells1[0]
            let under = below(first)
            let diagonal = cells2.first { $0 != under } ?? cells2[0]
            return ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(first, digit), state: .on)]),
                ProofBeat(nodes: [
                    ProofNode(node: node(other, digit), state: .off, cause: (node(first, digit), false)),
                    ProofNode(node: node(under, digit), state: .off, cause: (node(first, digit), false)),
                ], caption: String(localized: "Then \(digit) can't be in the other cell of either line.")),
                ProofBeat(nodes: [ProofNode(node: node(diagonal, digit), state: .on, cause: (node(under, digit), true))]),
            ])
        }
    }

    private func wingCases() -> [ProofCase] {
        guard let z = removedDigits.single else { return [] }
        let (pivot, pincer1, pincer2) = (cell(0), cell(1), cell(2))
        let pivotDigits = board.candidates(at: pivot)
        var result: [ProofCase] = []
        for pincer in [pincer1, pincer2] {
            guard let shared = board.candidates(at: pincer).intersection(pivotDigits).subtracting([z]).single else { continue }
            result.append(ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(pivot, shared), state: .on)]),
                ProofBeat(nodes: [ProofNode(node: node(pincer, shared), state: .off, cause: (node(pivot, shared), false))]),
                ProofBeat(nodes: [ProofNode(node: node(pincer, z), state: .on, cause: (node(pincer, shared), true))]),
            ]))
        }
        if step.technique == .xyzWing {
            result.append(single(node(pivot, z), .on))
        }
        return result
    }

    private func wWingCases() -> [ProofCase] {
        guard let y = removedDigits.single else { return [] }
        let x = step.patternDigits.subtracting([y]).min() ?? 0
        let (cell1, cell2, link1, link2) = (cell(0), cell(1), cell(2), cell(3))
        return [
            ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(link1, x), state: .on)]),
                ProofBeat(nodes: [ProofNode(node: node(cell1, x), state: .off, cause: (node(link1, x), false))]),
                ProofBeat(nodes: [ProofNode(node: node(cell1, y), state: .on, cause: (node(cell1, x), true))]),
            ]),
            ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(link1, x), state: .off)]),
                ProofBeat(nodes: [ProofNode(node: node(link2, x), state: .on, cause: (node(link1, x), true))]),
                ProofBeat(nodes: [ProofNode(node: node(cell2, x), state: .off, cause: (node(link2, x), false))]),
                ProofBeat(nodes: [ProofNode(node: node(cell2, y), state: .on, cause: (node(cell2, x), true))]),
            ]),
        ]
    }

    private func remotePairCases() -> [ProofCase] {
        let cells = step.patternCells
        let a = step.patternDigits.min() ?? 0
        let b = step.patternDigits.max() ?? 0
        return [a, b].map { first in
            var beats: [ProofBeat] = []
            var current = first
            for (index, cell) in cells.enumerated() {
                var proofNode = ProofNode(node: node(cell, current), state: .on)
                if index > 0 {
                    let previous = current == a ? b : a
                    // The neighbor holds the other digit, so this cell can't: it takes the remaining one.
                    proofNode.cause = (node(cells[index - 1], previous), false)
                }
                beats.append(ProofBeat(nodes: [proofNode]))
                current = current == a ? b : a
            }
            return ProofCase(beats: beats)
        }
    }

    private func emptyRectangleCases() -> [ProofCase] {
        let (box, crossed, kept) = (house(0), house(2), house(3))
        let (x, y) = (cell(0), cell(1))
        let boxCells = Array(step.patternCells.dropFirst(2))
        let crossedCells = boxCells.filter { crossed.contains($0) && !kept.contains($0) }
        let keptCells = boxCells.filter { kept.contains($0) }
        return [
            ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(x, digit), state: .on)]),
                ProofBeat(nodes: crossedCells.map { ProofNode(node: node($0, digit), state: .off, cause: (node(x, digit), false)) },
                          caption: String(localized: "Then \(digit) can't be on \(HintText.houseName(crossed)) inside \(HintText.houseName(box)).")),
                ProofBeat(nodes: keptCells.map { ProofNode(node: node($0, digit), state: .somewhere) },
                          caption: String(localized: "So inside \(HintText.houseName(box)), \(digit) is on \(HintText.houseName(kept)).")),
            ]),
            ProofCase(beats: [
                ProofBeat(nodes: [ProofNode(node: node(x, digit), state: .off)]),
                ProofBeat(nodes: [ProofNode(node: node(y, digit), state: .on, cause: (node(x, digit), true))]),
            ]),
        ]
    }

    private func coloringCases() -> [ProofCase] {
        let chain = SimpleColoring.chain(of: digit, startingAt: cell(0), in: board)
        let eliminated = Set(step.eliminations.map(\.cell))
        let isWrap = eliminated.isSubset(of: chain.cells.map(\.cell))
        return [chain.colorA, chain.colorB].map { color in
            let others = color == chain.colorA ? chain.colorB : chain.colorA
            var beats = [
                ProofBeat(nodes: color.map { ProofNode(node: node($0, digit), state: .on) },
                          caption: String(localized: "Suppose every cell of one color holds \(digit).")),
                ProofBeat(nodes: others.map { ProofNode(node: node($0, digit), state: .off) },
                          caption: String(localized: "Each strong link then rules \(digit) out of the cells of the other color.")),
            ]
            var contradiction: String?
            if isWrap, Set(color).isSubset(of: eliminated) {
                contradiction = String(localized: "But two cells of this color see each other, so they can't both be \(digit). This case is impossible.")
                beats.removeLast()
            }
            return ProofCase(beats: beats, contradiction: contradiction)
        }
    }

    private func finnedFishCases() -> [ProofCase] {
        let size = (step.focusHouses.count - 1) / 2
        let covers = Array(step.focusHouses.dropFirst(size).prefix(size))
        let fins = step.patternCells.filter { cell in !covers.contains { $0.contains(cell) } }
        let fishName = size == 2 ? TechniqueKind.xWing.title : TechniqueKind.swordfish.title
        return [
            ProofCase(beats: [ProofBeat(
                nodes: fins.map { ProofNode(node: node($0, digit), state: .off) },
                caption: String(localized: "Case 1 of 2: suppose the fin isn't \(digit). Then the rest is an ordinary \(fishName), and its lines can't have \(digit) anywhere else.")
            )]),
            ProofCase(beats: [ProofBeat(
                nodes: fins.prefix(1).map { ProofNode(node: node($0, digit), state: .on) },
                caption: String(localized: "Case 2 of 2: suppose the fin is \(digit). Then every cell it sees can't be \(digit).")
            )]),
        ]
    }

    private func alsCases() -> [ProofCase] {
        guard step.cellGroups.count == 2, let z = removedDigits.single else { return [] }
        let x = step.patternDigits.subtracting([z]).min() ?? 0
        return [0, 1].map { index in
            let without = step.cellGroups[index]
            return ProofCase(beats: [
                ProofBeat(nodes: without.filter { board.candidates(at: $0).contains(x) }.map { ProofNode(node: node($0, x), state: .off) },
                          caption: String(localized: "Case \(index + 1) of 2: \(x) is not in this group. Its other digits must then fill its cells, \(z) included.")),
                ProofBeat(nodes: without.filter { board.candidates(at: $0).contains(z) }.map { ProofNode(node: node($0, z), state: .somewhere) },
                          caption: String(localized: "So \(z) is in one of the cells marked in green.")),
            ].filter { !$0.nodes.isEmpty })
        }
    }

    // MARK: Playing cases

    private mutating func play(_ cases: [ProofCase]) {
        guard !cases.isEmpty else {
            addConclusion()
            return
        }
        for (index, proofCase) in cases.enumerated() {
            var highlights = base
            var shown: [ProofNode] = []
            for (beatIndex, beat) in proofCase.beats.enumerated() {
                for proofNode in beat.nodes {
                    draw(proofNode, on: &highlights)
                    shown.append(proofNode)
                }
                let text = beat.caption ?? caption(for: beat.nodes.first, isFirst: beatIndex == 0, caseIndex: index, caseCount: cases.count)
                add(text, highlights)
            }
            if let contradiction = proofCase.contradiction {
                add(contradiction, highlights)
                continue
            }
            // What this case rules out, with the reason for each target.
            for elimination in step.eliminations {
                highlights.fill([elimination.cell], .target)
                highlights.mark(elimination.digits, in: elimination.cell, as: .eliminated)
                for digit in elimination.digits {
                    if let reason = shown.first(where: { $0.state != .off && $0.node.digit == digit && Geometry.sees($0.node.cell, elimination.cell) }) {
                        highlights.link(reason.node, node(elimination.cell, digit), isStrong: false)
                    }
                }
            }
            add(String(localized: "In this case, \(HintText.digitList(removedDigits)) can't go in the cells marked in red."), highlights)
        }
        addConclusion()
    }

    private func draw(_ proofNode: ProofNode, on highlights: inout HintHighlights) {
        let (cell, digit) = (proofNode.node.cell, proofNode.node.digit)
        switch proofNode.state {
        case .on:
            highlights.ghost(digit, in: cell)
        case .off:
            highlights.mark([digit], in: cell, as: .eliminated)
        case .somewhere:
            highlights.mark([digit], in: cell, as: .alternativeA)
        }
        if let cause = proofNode.cause {
            highlights.link(cause.node, proofNode.node, isStrong: cause.isStrong)
        }
    }

    private func caption(for proofNode: ProofNode?, isFirst: Bool, caseIndex: Int, caseCount: Int) -> String {
        guard let proofNode else { return "" }
        let (cell, digit) = (name(proofNode.node.cell), proofNode.node.digit)
        let number = caseIndex + 1
        if isFirst {
            return proofNode.state == .off
                ? String(localized: "Case \(number) of \(caseCount): suppose \(digit) is not in the cell at \(cell).")
                : String(localized: "Case \(number) of \(caseCount): suppose \(digit) is in the cell at \(cell).")
        }
        switch proofNode.state {
        case .on: return String(localized: "Then the cell at \(cell) must be \(digit).")
        case .off: return String(localized: "Then the cell at \(cell) can't be \(digit).")
        case .somewhere: return String(localized: "So \(digit) is in one of the cells marked in green.")
        }
    }

    /// Last frame: the step's result, with every target struck (or the digit placed).
    private mutating func addConclusion() {
        var highlights = base
        for elimination in step.eliminations {
            highlights.fill([elimination.cell], .target)
            highlights.mark(elimination.digits, in: elimination.cell, as: .eliminated)
        }
        for placement in step.placements {
            highlights.ghost(placement.digit, in: placement.cell)
        }
        let text = if let placement = step.placements.first {
            String(localized: "So \(placement.digit) goes in the cell at \(name(placement.cell)).")
        } else {
            String(localized: "Every case rules it out, so \(HintText.digitList(removedDigits)) can be removed from the cells marked in red.")
        }
        add(text, highlights, kind: .result)
    }

    // MARK: Techniques shown without cases

    /// Singles: lines from each placed digit to the candidates it rules out.
    private mutating func singles() {
        guard let placement = step.placements.first else { return }
        let target = placement.cell
        var highlights = base
        switch step.technique {
        case .hiddenSingle:
            // One frame per digit that blocks other cells of the house.
            var blocked = Set<CellIndex>()
            for other in house(0).cells where other != target && board.value(at: other) == 0 {
                guard !blocked.contains(other),
                      let blocker = Geometry.peers[other].first(where: { board.value(at: $0) == placement.digit })
                else { continue }
                highlights.fill([blocker], .blocker)
                for cell in house(0).cells where cell != target && board.value(at: cell) == 0 && Geometry.sees(cell, blocker) && !blocked.contains(cell) {
                    blocked.insert(cell)
                    highlights.mark([placement.digit], in: cell, as: .eliminated)
                    highlights.link(node(blocker, placement.digit), node(cell, placement.digit), isStrong: false)
                }
                add(String(localized: "The \(placement.digit) in the cell at \(name(blocker)) rules \(placement.digit) out of the cells it sees."), highlights)
            }
        case .nakedSingle:
            let seen = Geometry.peers[target].filter { board.value(at: $0) != 0 }
            highlights.fill(seen, .blocker)
            for cell in seen {
                let value = board.value(at: cell)
                highlights.mark([value], in: target, as: .eliminated)
                highlights.link(node(cell, value), node(target, value), isStrong: false)
            }
            add(String(localized: "Every digit in its row, column and box rules itself out of the cell at \(name(target))."), highlights)
        default:
            break
        }
        addConclusion()
    }

    private mutating func bug() {
        var highlights = base
        for cell in board.emptyCells where board.candidates(at: cell).count == 2 {
            highlights.showCandidates(board.candidates(at: cell), in: cell)
        }
        add(String(localized: "Look at every empty cell: all of them have exactly two candidates except one."), highlights)
        addConclusion()
    }

    /// One frame per digit of the subset, showing where it can go in the house.
    private mutating func hiddenSubset() {
        for digit in step.patternDigits {
            var highlights = base
            for cell in house(0).cells where board.candidates(at: cell).contains(digit) {
                highlights.mark([digit], in: cell, as: .alternativeA)
            }
            add(String(localized: "In \(HintText.houseName(house(0))), \(digit) can only go in the cells marked in green."), highlights)
        }
        addConclusion()
    }

    /// One frame per base line, then the cover lines.
    private mutating func largeFish() {
        let size = step.focusHouses.count / 2
        var highlights = base
        for line in step.focusHouses.prefix(size) {
            for cell in line.cells where board.candidates(at: cell).contains(digit) {
                highlights.mark([digit], in: cell, as: .alternativeA)
            }
            add(String(localized: "In \(HintText.houseName(line)), \(digit) can only go in the cells marked in green."), highlights)
        }
        addConclusion()
    }

    /// The deadly pattern: both ways of filling the corners with the two digits would work.
    private mutating func uniqueRectangle() {
        let corners = Array(step.patternCells.prefix(4))
        let a = step.patternDigits.min() ?? 0
        let b = step.patternDigits.max() ?? 0
        // Diagonal corners hold the same digit.
        let first = corners[0]
        for (swap, text) in [(false, String(localized: "If the four corners held only \(a) and \(b), they could be filled like this...")),
                             (true, String(localized: "...or with the two digits swapped. Both would fit, so the puzzle would have two solutions."))] {
            var highlights = base
            for corner in corners {
                let sameAsFirst = Geometry.row(of: corner) == Geometry.row(of: first) ? Geometry.column(of: corner) == Geometry.column(of: first) : Geometry.column(of: corner) != Geometry.column(of: first)
                highlights.ghost(sameAsFirst != swap ? a : b, in: corner)
            }
            add(text, highlights)
        }
        let pages = HintWalkthrough.pages(for: .step(step, board: board)).filter { $0.kind == .explanation }
        if let reasoning = pages.last?.text {
            add(reasoning, base)
        }
        addConclusion()
    }
}
