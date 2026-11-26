//
//  PuzzleCode.swift
//  Sudoku
//

/// A short text that recreates a puzzle, for sharing it or playing it again.
///
/// The code holds the givens exactly as the player sees them (after any transform), so it never
/// depends on the bundled bank: a regenerated bank, or a puzzle made on the device, still works.
/// Digits are written as they are and each run of empty cells as one letter, `a` for one empty cell
/// up to `z` for 26, behind a version prefix: `S1-` followed by about 45 characters.
enum PuzzleCode {
    static let prefix = "S1-"

    static func code(for givens: [Digit]) -> String {
        var code = prefix
        var empty = 0
        func flush() {
            while empty > 0 {
                let run = min(empty, 26)
                code.append(Character(UnicodeScalar(UInt8(96 + run))))
                empty -= run
            }
        }
        for digit in givens {
            if digit == 0 {
                empty += 1
            } else {
                flush()
                code.append(Character(String(digit)))
            }
        }
        flush()
        return code
    }

    /// The givens in `code`, or `nil` when it isn't a code. Spaces and letter case are forgiven, as a
    /// pasted code may carry either.
    static func givens(from code: String) -> [Digit]? {
        let text = String(code.lowercased().drop(while: \.isWhitespace))
        guard text.hasPrefix(prefix.lowercased()) else { return nil }
        var givens: [Digit] = []
        for character in text.dropFirst(prefix.count) where !character.isWhitespace {
            if let digit = character.wholeNumberValue, (1...9).contains(digit), character.isASCII {
                givens.append(digit)
            } else if let ascii = character.asciiValue, (97...122).contains(ascii) {
                givens.append(contentsOf: repeatElement(0, count: Int(ascii) - 96))
            } else {
                return nil
            }
            if givens.count > Geometry.cellCount { return nil }
        }
        return givens.count == Geometry.cellCount ? givens : nil
    }

    /// The puzzle a code stands for, graded like any other: `nil` unless it has exactly one solution
    /// and the logical solver can finish it, as every puzzle this app makes can.
    static func puzzle(from code: String) -> Puzzle? {
        guard let givens = givens(from: code),
              BruteForceSolver.hasUniqueSolution(givens),
              let solution = BruteForceSolver.solution(of: givens)
        else { return nil }
        let result = LogicalSolver().solve(Board(values: givens))
        guard result.isSolved, let difficulty = Difficulty(rawValue: result.hardestTechnique?.level ?? 1) else { return nil }
        return Puzzle.graded(givens: givens, solution: solution, difficulty: difficulty, result: result)
    }
}
