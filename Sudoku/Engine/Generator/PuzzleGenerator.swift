//
//  PuzzleGenerator.swift
//  Sudoku
//

/// Builds puzzles with a unique solution whose difficulty is graded by `LogicalSolver`.
///
/// 1. Create a random solved grid.
/// 2. Remove clues in 180°-symmetric pairs, keeping a removal only if the puzzle still has a unique
///    solution and stays solvable with techniques up to the target level.
/// 3. Accept the result only if its hardest required technique is exactly the target level.
enum PuzzleGenerator {
    /// Difficulties the current technique set can grade. Grows as techniques are added.
    static let supportedDifficulties: Set<Difficulty> = [.easy, .medium]

    /// Generates a puzzle off the main actor using the system random number generator.
    @concurrent
    static func generate(_ difficulty: Difficulty) async -> Puzzle {
        var generator = SystemRandomNumberGenerator()
        return generate(difficulty, using: &generator)
    }

    /// Generates a puzzle deterministically from `generator`.
    static func generate(_ difficulty: Difficulty, using generator: inout some RandomNumberGenerator) -> Puzzle {
        precondition(supportedDifficulties.contains(difficulty), "No technique set can grade \(difficulty) yet")
        while true {
            let solution = makeSolvedGrid(using: &generator)
            let givens = removeClues(from: solution, difficulty: difficulty, using: &generator)
            if hardestLevel(of: givens) == difficulty.level {
                return Puzzle(givens: givens, solution: solution, difficulty: difficulty)
            }
        }
    }

    /// A random complete grid. The three diagonal boxes don't constrain each other, so they are filled
    /// with random permutations and the brute-force solver completes the rest.
    static func makeSolvedGrid(using generator: inout some RandomNumberGenerator) -> [Digit] {
        var values = Array(repeating: 0, count: Geometry.cellCount)
        for box in [0, 4, 8] {
            var digits = Array(Geometry.digits)
            digits.stableShuffle(using: &generator)
            for (cell, digit) in zip(House(kind: .box, index: box).cells, digits) {
                values[cell] = digit
            }
        }
        guard let solution = BruteForceSolver.solution(of: values) else {
            preconditionFailure("Independent diagonal boxes always complete to a valid grid")
        }
        return solution
    }

    /// Fewest clues to leave. Fewer clues make a puzzle feel harder even at the same technique level,
    /// so easier difficulties stop early.
    static func minimumGivens(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 36
        case .medium: 30
        case .hard: 26
        case .expert, .master: 22
        }
    }

    private static func removeClues(
        from solution: [Digit],
        difficulty: Difficulty,
        using generator: inout some RandomNumberGenerator
    ) -> [Digit] {
        // Cell `i` pairs with `80 - i` under 180° rotation; the center cell stands alone.
        var pairs = (0...40).map { $0 == 40 ? [40] : [$0, 80 - $0] }
        pairs.stableShuffle(using: &generator)

        var givens = solution
        var givenCount = Geometry.cellCount
        let minimum = minimumGivens(for: difficulty)
        for pair in pairs where givenCount - pair.count >= minimum {
            for cell in pair {
                givens[cell] = 0
            }
            if isAcceptable(givens, maximumLevel: difficulty.level) {
                givenCount -= pair.count
            } else {
                for cell in pair {
                    givens[cell] = solution[cell]
                }
            }
        }
        return givens
    }

    private static func isAcceptable(_ givens: [Digit], maximumLevel: Int) -> Bool {
        guard BruteForceSolver.hasUniqueSolution(givens), let level = hardestLevel(of: givens) else { return false }
        return level <= maximumLevel
    }

    /// Level of the hardest technique needed, or `nil` if the logical solver can't finish.
    private static func hardestLevel(of givens: [Digit]) -> Int? {
        let result = LogicalSolver().solve(Board(values: givens))
        guard result.isSolved else { return nil }
        return result.hardestTechnique?.level ?? 1
    }
}
