//
//  main.swift
//  PuzzleBankGenerator
//
//  Builds Sudoku/Resources/PuzzleBank.json with the app's own engine, compiled for the Mac.
//  Run Tools/generate-puzzle-bank.sh instead of calling this directly.
//
//  Usage: PuzzleBankGenerator <output.json> <puzzles per difficulty>
//

import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3, let perDifficulty = Int(arguments[2]), perDifficulty > 0 else {
    print("Usage: PuzzleBankGenerator <output.json> <puzzles per difficulty>")
    exit(1)
}
let outputURL = URL(filePath: arguments[1])

/// Collects results from many threads.
final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var puzzles: [Int: Puzzle] = [:]

    func add(_ puzzle: Puzzle, at index: Int) {
        lock.withLock { puzzles[index] = puzzle }
    }

    var ordered: [Puzzle] {
        lock.withLock { puzzles.sorted { $0.key < $1.key }.map(\.value) }
    }
}

var file = PuzzleBank.File(version: PuzzleBank.fileVersion, puzzles: [:])
for difficulty in Difficulty.allCases {
    let start = Date()
    let collector = Collector()
    // Fixed seeds per difficulty and index make the bank reproducible.
    DispatchQueue.concurrentPerform(iterations: perDifficulty) { index in
        var generator = SeededRandomNumberGenerator(seed: UInt64(difficulty.rawValue) << 32 | UInt64(index))
        collector.add(PuzzleGenerator.generate(difficulty, using: &generator), at: index)
    }

    // Different seeds can, rarely, produce the same puzzle; keep each once.
    var seen = Set<String>()
    let entries = collector.ordered.map(PuzzleBank.entry(for:)).filter { seen.insert($0.givens).inserted }
    file.puzzles[String(difficulty.rawValue)] = entries

    let average = entries.map(\.estimatedSeconds).reduce(0, +) / max(entries.count, 1)
    print("\(difficulty): \(entries.count) puzzles in \(Int(Date().timeIntervalSince(start)))s, average estimate \(average / 60) min")
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
try encoder.encode(file).write(to: outputURL, options: .atomic)
print("Wrote \(outputURL.path(percentEncoded: false))")
