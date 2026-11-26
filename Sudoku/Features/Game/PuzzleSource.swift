//
//  PuzzleSource.swift
//  Sudoku
//

import Foundation

/// Hands out puzzles for new games. Stored puzzles come from the bundled bank in a shuffled order
/// that doesn't repeat until every puzzle of that difficulty has been played, each with a fresh
/// random transform so even a repeat looks new. If the bank has nothing for a difficulty, the
/// generator makes one instead.
@MainActor
final class PuzzleSource {
    static let shared = PuzzleSource()

    private let bank: PuzzleBank
    private let defaults: UserDefaults

    init(bank: PuzzleBank = .bundled, defaults: UserDefaults = .standard) {
        self.bank = bank
        self.defaults = defaults
    }

    func puzzle(_ difficulty: Difficulty) async -> Puzzle {
        if let index = nextIndex(for: difficulty), let stored = bank.puzzle(difficulty, at: index) {
            // A seed in the range a short puzzle code can carry.
            let seed = UInt32.random(in: 0..<PuzzleCode.seedLimit)
            var puzzle = PuzzleTransform.seeded(seed).apply(to: stored)
            puzzle.origin = Puzzle.Origin(index: index, seed: seed)
            return puzzle
        }
        return await PuzzleGenerator.generate(difficulty)
    }

    /// The next bank index for `difficulty`. The order is a shuffle of all indices fixed by a stored
    /// seed; a stored position walks through it, and a new seed starts the next round.
    func nextIndex(for difficulty: Difficulty) -> Int? {
        let count = bank.count(of: difficulty)
        guard count > 0 else { return nil }
        let seedKey = "puzzleBank.\(difficulty.rawValue).seed"
        let positionKey = "puzzleBank.\(difficulty.rawValue).position"

        var position = defaults.integer(forKey: positionKey)
        var seed = (defaults.object(forKey: seedKey) as? Int).map { UInt64(bitPattern: Int64($0)) }
        if seed == nil || position >= count {
            seed = UInt64.random(in: .min ... .max)
            position = 0
        }
        guard let seed else { return nil }

        var generator = SeededRandomNumberGenerator(seed: seed)
        var order = Array(0..<count)
        order.stableShuffle(using: &generator)

        defaults.set(Int(Int64(bitPattern: seed)), forKey: seedKey)
        defaults.set(position + 1, forKey: positionKey)
        return order[position]
    }
}
