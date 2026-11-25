//
//  PuzzleBank.swift
//  Sudoku
//

import Foundation

/// Puzzles generated and graded ahead of time (see `Tools/PuzzleBankGenerator`) and shipped as
/// `PuzzleBank.json`, so starting a game never waits for the generator. Combined with
/// `PuzzleTransform`, every stored puzzle can be played in many different-looking versions.
struct PuzzleBank: Sendable {
    /// One stored puzzle. Digits are 81-character strings, `.` for an empty cell.
    struct Entry: Codable, Hashable, Sendable {
        let givens: String
        let solution: String
        let estimatedSeconds: Int
        let techniques: [String]
    }

    /// The file's layout: a format version and the entries per difficulty (keyed by raw value).
    struct File: Codable, Sendable {
        var version: Int
        var puzzles: [String: [Entry]]
    }

    static let fileVersion = 1

    private let entries: [Difficulty: [Entry]]

    init(file: File) {
        var entries: [Difficulty: [Entry]] = [:]
        for (key, list) in file.puzzles {
            if let raw = Int(key), let difficulty = Difficulty(rawValue: raw) {
                entries[difficulty] = list
            }
        }
        self.entries = entries
    }

    init(data: Data) throws {
        self.init(file: try JSONDecoder().decode(File.self, from: data))
    }

    /// The bank shipped with the app, or an empty bank if the file is missing or unreadable (the
    /// generator then takes over).
    static let bundled: PuzzleBank = {
        guard let url = Bundle.main.url(forResource: "PuzzleBank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? PuzzleBank(data: data)
        else { return PuzzleBank(file: File(version: fileVersion, puzzles: [:])) }
        return bank
    }()

    func count(of difficulty: Difficulty) -> Int {
        entries[difficulty]?.count ?? 0
    }

    /// The stored puzzle at `index` for `difficulty`, as is (no transform).
    func puzzle(_ difficulty: Difficulty, at index: Int) -> Puzzle? {
        guard let list = entries[difficulty], list.indices.contains(index) else { return nil }
        let entry = list[index]
        guard let givens = Self.values(entry.givens), let solution = Self.values(entry.solution) else { return nil }
        return Puzzle(
            givens: givens,
            solution: solution,
            difficulty: difficulty,
            estimatedSeconds: entry.estimatedSeconds,
            requiredTechniques: entry.techniques.compactMap(TechniqueKind.init(rawValue:))
        )
    }

    /// Turns a generated puzzle into a stored entry.
    static func entry(for puzzle: Puzzle) -> Entry {
        Entry(
            givens: string(puzzle.givens),
            solution: string(puzzle.solution),
            estimatedSeconds: puzzle.estimatedSeconds ?? 0,
            techniques: (puzzle.requiredTechniques ?? []).map(\.rawValue)
        )
    }

    static func string(_ values: [Digit]) -> String {
        String(values.map { $0 == 0 ? "." : Character(String($0)) })
    }

    static func values(_ string: String) -> [Digit]? {
        let values = string.map { character -> Digit in
            character.wholeNumberValue ?? 0
        }
        return values.count == Geometry.cellCount ? values : nil
    }
}
