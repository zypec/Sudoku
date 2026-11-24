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

    init(givens: [Digit], solution: [Digit], difficulty: Difficulty) {
        precondition(givens.count == Geometry.cellCount && solution.count == Geometry.cellCount, "A puzzle needs 81 cells")
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
    }

    var givenCount: Int {
        givens.count { $0 != 0 }
    }
}
