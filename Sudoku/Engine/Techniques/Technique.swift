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

    /// Difficulty tier `1...5` (basic … master). A puzzle's difficulty is the highest
    /// level among the techniques it requires.
    var level: Int {
        switch self {
        case .fullHouse, .hiddenSingle, .nakedSingle:
            1
        case .pointing, .claiming, .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple:
            2
        case .nakedQuad, .hiddenQuad:
            3
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
/// highlight to explain it. Contains no text — explanations are localized in the UI layer.
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
}

/// A human solving technique. Implementations look at the board's current candidates and
/// return the first deduction they can make, or `nil` if the technique doesn't apply.
protocol Technique: Sendable {
    var kind: TechniqueKind { get }
    func findStep(in board: Board) -> SolveStep?
}

extension Board {
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
