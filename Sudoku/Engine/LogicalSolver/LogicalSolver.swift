//
//  LogicalSolver.swift
//  Sudoku
//

/// Solves like an experienced player: at every step it tries techniques from easiest to hardest
/// and takes the first deduction it finds. It never guesses.
struct LogicalSolver: Sendable {
    /// Techniques in the order they are tried. Hidden singles come before naked singles because
    /// they are easier to spot without pencil marks; within a level, smaller patterns come first.
    static let standardTechniques: [any Technique] = [
        // Level 1
        FullHouse(),
        HiddenSingle(),
        NakedSingle(),
        // Level 2
        Pointing(),
        Claiming(),
        NakedSubset(size: 2),
        HiddenSubset(size: 2),
        NakedSubset(size: 3),
        HiddenSubset(size: 3),
        // Level 3
        NakedSubset(size: 4),
        HiddenSubset(size: 4),
    ]

    let techniques: [any Technique]

    init(techniques: [any Technique] = LogicalSolver.standardTechniques) {
        self.techniques = techniques
    }

    /// The easiest deduction available on `board`, or `nil` if the board is solved,
    /// contradictory, or beyond the known techniques.
    func nextStep(on board: Board) -> SolveStep? {
        guard !board.isSolved, !board.isContradictory else { return nil }
        for technique in techniques {
            if let step = technique.findStep(in: board) {
                return step
            }
        }
        return nil
    }

    /// Applies deductions until the board is solved or no technique makes progress.
    func solve(_ board: Board) -> SolveResult {
        var board = board
        var steps: [SolveStep] = []
        while let step = nextStep(on: board) {
            let before = board
            board.apply(step)
            // A step that changes nothing would loop forever; treat it as a technique bug.
            guard board != before else {
                assertionFailure("\(step.technique) produced a step without progress")
                break
            }
            steps.append(step)
        }
        return SolveResult(steps: steps, board: board)
    }
}

/// Outcome of running `LogicalSolver.solve(_:)`.
struct SolveResult: Sendable {
    /// Every deduction made, in order.
    let steps: [SolveStep]
    /// The board after the last step.
    let board: Board

    var isSolved: Bool { board.isSolved }

    /// The hardest technique used, which defines the puzzle's difficulty.
    var hardestTechnique: TechniqueKind? {
        steps.map(\.technique).max { $0.level < $1.level }
    }

    /// How many times each technique was used.
    var techniqueCounts: [TechniqueKind: Int] {
        steps.reduce(into: [:]) { $0[$1.technique, default: 0] += 1 }
    }
}
