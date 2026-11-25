//
//  main.swift
//  PuzzleBankGenerator
//
//  Builds Sudoku/Resources/PuzzleBank.json with the app's own engine, compiled for the Mac.
//  Run Tools/generate-puzzle-bank.sh instead of calling this directly.
//
//  Usage: PuzzleBankGenerator <output.json> <puzzles per difficulty>
//         PuzzleBankGenerator positions <bank.json> <output.json> <positions per technique>
//

import Foundation

let arguments = CommandLine.arguments

// Training positions: read the bank and record, per puzzle, where each technique is first needed.
if arguments.count == 5, arguments[1] == "positions", let limit = Int(arguments[4]) {
    let bank = try PuzzleBank(data: Data(contentsOf: URL(filePath: arguments[2])))
    // Alternate difficulties so each technique's positions come from varied puzzles.
    let longest = Difficulty.allCases.map(bank.count(of:)).max() ?? 0
    var puzzles: [Puzzle] = []
    for index in 0..<longest {
        for difficulty in Difficulty.allCases.reversed() {
            if let puzzle = bank.puzzle(difficulty, at: index) {
                puzzles.append(puzzle)
            }
        }
    }
    let file = TrainingPositions.extract(from: puzzles, limit: limit)
    for technique in TechniqueKind.allCases {
        print("\(technique): \(file.positions[technique.rawValue]?.count ?? 0)")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(file).write(to: URL(filePath: arguments[3]), options: .atomic)
    print("Wrote \(arguments[3])")
    exit(0)
}

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
