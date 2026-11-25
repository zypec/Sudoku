//
//  Puzzle.swift
//  Sudoku
//

/// Difficulty of a puzzle, defined by the hardest technique level needed to solve it.
enum Difficulty: Int, CaseIterable, Codable, Sendable, Identifiable {
    case easy = 1
    case medium
    case hard
    case expert
    case master

    var id: Int { rawValue }

    /// Highest technique level (`TechniqueKind.level`) a puzzle of this difficulty requires.
    var level: Int { rawValue }
}

/// A puzzle with a unique solution.
struct Puzzle: Hashable, Codable, Sendable {
    /// Starting digits, `0` for empty cells.
    let givens: [Digit]
    let solution: [Digit]
    let difficulty: Difficulty
    /// Estimated seconds for a typical player (`SolveTimeEstimate`). `nil` in games saved before
    /// estimates existed.
    var estimatedSeconds: Int?
    /// Techniques the logical solver needs for this puzzle, easiest first. `nil` in older saves.
    var requiredTechniques: [TechniqueKind]?

    init(givens: [Digit], solution: [Digit], difficulty: Difficulty, estimatedSeconds: Int? = nil, requiredTechniques: [TechniqueKind]? = nil) {
        precondition(givens.count == Geometry.cellCount && solution.count == Geometry.cellCount, "A puzzle needs 81 cells")
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
        self.estimatedSeconds = estimatedSeconds
        self.requiredTechniques = requiredTechniques
    }

    /// The puzzle with its estimate and required techniques worked out by the logical solver.
    static func graded(givens: [Digit], solution: [Digit], difficulty: Difficulty, result: SolveResult) -> Puzzle {
        let used = Set(result.steps.map(\.technique))
        return Puzzle(
            givens: givens,
            solution: solution,
            difficulty: difficulty,
            estimatedSeconds: SolveTimeEstimate.seconds(givens: givens, result: result),
            requiredTechniques: TechniqueKind.allCases.filter(used.contains)
        )
    }

    var givenCount: Int {
        givens.count { $0 != 0 }
    }
}
