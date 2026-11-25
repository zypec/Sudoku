//
//  Technique.swift
//  Sudoku
//

/// Every human solving technique the engine knows, ordered from easiest to hardest.
enum TechniqueKind: String, CaseIterable, Codable, Sendable {
    case fullHouse
    case hiddenSingle
    case nakedSingle
    case pointing
    case claiming
    case nakedPair
    case hiddenPair
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case skyscraper
    case twoStringKite
    case xyWing
    case xyzWing
    case wWing
    case uniqueRectangleType1
    case swordfish
    case emptyRectangle
    case simpleColoring
    case finnedXWing
    case uniqueRectangleType2
    case uniqueRectangleType4
    case bug
    case finnedSwordfish
    case jellyfish
    case remotePair
    case xChain
    case xyChain
    case aic
    case alsXZ

    /// Difficulty tier `1...5` (basic to master). A puzzle's difficulty is the highest
    /// level among the techniques it requires.
    var level: Int {
        switch self {
        case .fullHouse, .hiddenSingle, .nakedSingle:
            1
        case .pointing, .claiming, .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple:
            2
        case .nakedQuad, .hiddenQuad, .xWing, .skyscraper, .twoStringKite, .xyWing, .xyzWing, .wWing:
            3
        case .uniqueRectangleType1, .swordfish, .emptyRectangle, .simpleColoring, .finnedXWing,
             .uniqueRectangleType2, .uniqueRectangleType4, .bug, .finnedSwordfish, .jellyfish:
            4
        case .remotePair, .xChain, .xyChain, .aic, .alsXZ:
            5
        }
    }
}

/// A digit that a step places in a cell.
struct Placement: Hashable, Sendable, Codable {
    let cell: CellIndex
    let digit: Digit
}

/// Candidates that a step removes from a cell.
struct Elimination: Hashable, Sendable, Codable {
    let cell: CellIndex
    let digits: CandidateSet
}

/// One logical deduction: what was found, with which technique, and what the UI should
/// highlight to explain it. Contains no text; explanations are localized in the UI layer.
struct SolveStep: Hashable, Sendable {
    let technique: TechniqueKind
    var placements: [Placement] = []
    var eliminations: [Elimination] = []
    /// Houses the explanation is about (e.g. the box in which a digit has a single spot).
    var focusHouses: [House] = []
    /// Cells forming the pattern (e.g. X-Wing corners, or the target cell of a single).
    var patternCells: [CellIndex] = []
    /// Digits the pattern is about.
    var patternDigits: CandidateSet = []
    /// For chains: the candidates in order. Links alternate strong, weak, strong, … and the chain
    /// starts and ends with a strong link, so at least one of its two ends is true.
    var chain: [ChainNode] = []
    /// For patterns made of several groups of cells (ALS-XZ: the two almost locked sets).
    var cellGroups: [[CellIndex]] = []
}

/// A candidate: one digit in one cell. Chains are sequences of candidates.
struct ChainNode: Hashable, Sendable {
    let cell: CellIndex
    let digit: Digit
}

/// A human solving technique. Implementations look at the board's current candidates and
/// return the first deduction they can make, or `nil` if the technique doesn't apply.
protocol Technique: Sendable {
    var kind: TechniqueKind { get }
    func findStep(in board: Board) -> SolveStep?
}

extension Board {
    /// Cells of `house` that still have `digit` as a candidate. Two cells form a *strong link*
    /// (conjugate pair): exactly one of them holds the digit.
    func cells(in house: House, withCandidate digit: Digit) -> [CellIndex] {
        house.cells.filter { candidates(at: $0).contains(digit) }
    }

    /// Eliminations removing `digit` from those of `cells` that still have it.
    func eliminations(of digit: Digit, from cells: some Sequence<CellIndex>) -> [Elimination] {
        cells.compactMap { candidates(at: $0).contains(digit) ? Elimination(cell: $0, digits: [digit]) : nil }
    }

    /// Applies a step's placements and eliminations.
    mutating func apply(_ step: SolveStep) {
        for placement in step.placements {
            place(placement.digit, at: placement.cell)
        }
        for elimination in step.eliminations {
            eliminate(elimination.digits, from: elimination.cell)
        }
    }
}
