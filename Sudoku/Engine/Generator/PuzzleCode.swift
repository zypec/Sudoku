//
//  PuzzleCode.swift
//  Sudoku
//

/// A short text that recreates a puzzle, for sharing it or playing it again.
///
/// A puzzle from the bundled bank gets a short code: which puzzle of the bank it is and the seed of
/// the transform it is shown in, nine characters written in three groups (`H7K-2M4-Q9X`). The
/// characters are Crockford's base 32, which leaves out I, L, O and U, so a code read aloud or typed
/// by hand is hard to get wrong; an O or an I typed anyway is read as 0 or 1.
///
///   character 1      the bank's generation and the difficulty: generation * 5 + (level - 1)
///   characters 2-3   the puzzle's index in the bank for that difficulty (up to 1,023)
///   characters 4-9   the transform's seed (30 bits)
///
/// The generation changes whenever the bank is generated again (`bankGeneration`), so an old code
/// is refused rather than opening a different puzzle.
///
/// A puzzle that isn't from the bank (made on the device when the bank had none) is written out
/// whole instead: `S1-` and its givens, each digit as it is and each run of empty cells as one
/// letter, `a` for one empty cell up to `z` for 26, about 45 characters.
enum PuzzleCode {
    /// Raise by one after regenerating `PuzzleBank.json`: codes of the old bank then stop working
    /// instead of naming other puzzles.
    static let bankGeneration = 0
    /// Seeds a short code can carry.
    static let seedLimit: UInt32 = 1 << 30
    static let prefix = "S1-"

    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    /// The short code when the puzzle came from the bank, otherwise its givens written out.
    static func code(for puzzle: Puzzle) -> String {
        guard let origin = puzzle.origin, origin.index < 1024, origin.seed < seedLimit else {
            return code(for: puzzle.givens)
        }
        let head: Int = bankGeneration * 5 + puzzle.difficulty.level - 1
        var digits: [Int] = [head, origin.index >> 5, origin.index & 31]
        for shift in stride(from: 25, through: 0, by: -5) {
            digits.append(Int((origin.seed >> UInt32(shift)) & 31))
        }
        let text = String(digits.map { alphabet[$0] })
        return "\(text.prefix(3))-\(text.dropFirst(3).prefix(3))-\(text.suffix(3))"
    }

    /// The givens written out whole.
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

    /// The puzzle a code stands for, or `nil` when it stands for none: a short code of another bank or
    /// out of range, or a written-out puzzle without exactly one solution that the logical solver can
    /// finish, as every puzzle this app makes can. Spaces, dashes and letter case are forgiven.
    static func puzzle(from code: String, bank: PuzzleBank = .bundled) -> Puzzle? {
        if let givens = givens(from: code) {
            return graded(givens)
        }
        return shortPuzzle(from: code, bank: bank)
    }

    private static func shortPuzzle(from code: String, bank: PuzzleBank) -> Puzzle? {
        var values: [Int] = []
        for character in code.uppercased() where !character.isWhitespace && character != "-" {
            let read: Character = switch character {
            case "O": "0"
            case "I", "L": "1"
            default: character
            }
            guard let value = alphabet.firstIndex(of: read) else { return nil }
            values.append(value)
        }
        guard values.count == 9 else { return nil }
        let generation = values[0] / 5
        guard generation == bankGeneration, let difficulty = Difficulty(rawValue: values[0] % 5 + 1) else { return nil }
        let index = values[1] << 5 | values[2]
        let seed = values[3...].reduce(UInt32(0)) { $0 << 5 | UInt32($1) }
        guard var puzzle = bank.puzzle(difficulty, at: index).map(PuzzleTransform.seeded(seed).apply(to:)) else { return nil }
        puzzle.origin = Puzzle.Origin(index: index, seed: seed)
        return puzzle
    }

    /// The givens in a written-out code, or `nil` when it isn't one.
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

    private static func graded(_ givens: [Digit]) -> Puzzle? {
        guard BruteForceSolver.hasUniqueSolution(givens), let solution = BruteForceSolver.solution(of: givens) else { return nil }
        let result = LogicalSolver().solve(Board(values: givens))
        guard result.isSolved, let difficulty = Difficulty(rawValue: result.hardestTechnique?.level ?? 1) else { return nil }
        return Puzzle.graded(givens: givens, solution: solution, difficulty: difficulty, result: result)
    }
}
