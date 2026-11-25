//
//  main.swift
//  PuzzleBankGenerator
//
//  Builds Sudoku/Resources/PuzzleBank.json with the app's own engine, compiled for the Mac.
//  Run Tools/generate-puzzle-bank.sh instead of calling this directly.
//
//  Usage: PuzzleBankGenerator <output.json> <puzzles per difficulty>
//         PuzzleBankGenerator positions <bank.json> <output.json> <positions per technique>
//         PuzzleBankGenerator topup <positions.json> <positions per technique> <seconds>
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

// More positions for the techniques that have fewer than `limit`: random puzzles with a unique solution
// (not graded, so made fast) are walked with the logical solver, and the first time a short technique is
// needed, that moment is kept. A puzzle the solver can't finish still gives the positions before it stops.
if arguments.count == 5, arguments[1] == "topup", let limit = Int(arguments[3]), let seconds = Double(arguments[4]) {
    let url = URL(filePath: arguments[2])
    var file = try JSONDecoder().decode(TrainingPositions.File.self, from: Data(contentsOf: url))
    let wanted = Set(TechniqueKind.allCases.filter { (file.positions[$0.rawValue]?.count ?? 0) < limit })
    print("Looking for: \(wanted.map(\.rawValue).sorted().joined(separator: ", "))")

    final class Found: @unchecked Sendable {
        let lock = NSLock()
        var positions: [String: [TrainingPositions.Position]]
        var puzzles = 0
        init(_ positions: [String: [TrainingPositions.Position]]) { self.positions = positions }
    }
    let found = Found(file.positions)
    let deadline = Date().addingTimeInterval(seconds)
    DispatchQueue.concurrentPerform(iterations: ProcessInfo.processInfo.activeProcessorCount) { worker in
        var generator = SeededRandomNumberGenerator(seed: 0x70_0000_0000 | UInt64(worker) << 24 | UInt64(Date().timeIntervalSince1970) & 0xFFFFFF)
        let solver = LogicalSolver()
        while Date() < deadline {
            let solution = PuzzleGenerator.makeSolvedGrid(using: &generator)
            var pairs = (0...40).map { $0 == 40 ? [40] : [$0, 80 - $0] }
            pairs.stableShuffle(using: &generator)
            var givens = solution
            for pair in pairs {
                for cell in pair { givens[cell] = 0 }
                if !BruteForceSolver.hasUniqueSolution(givens) {
                    for cell in pair { givens[cell] = solution[cell] }
                }
            }
            var board = Board(values: givens)
            var seen = Set<TechniqueKind>()
            while let step = solver.nextStep(on: board) {
                if wanted.contains(step.technique), !seen.contains(step.technique), board.values.count(where: { $0 != 0 }) >= 22 {
                    seen.insert(step.technique)
                    let position = TrainingPositions.Position(board: board)
                    found.lock.withLock {
                        var list = found.positions[step.technique.rawValue, default: []]
                        if list.count < limit, !list.contains(position) {
                            list.append(position)
                            found.positions[step.technique.rawValue] = list
                        }
                    }
                }
                board.apply(step)
            }
            found.lock.withLock { found.puzzles += 1 }
        }
    }
    file.positions = found.positions
    print("\(found.puzzles) puzzles walked")
    for technique in wanted.sorted(by: { $0.rawValue < $1.rawValue }) {
        print("\(technique): \(file.positions[technique.rawValue]?.count ?? 0)")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(file).write(to: url, options: .atomic)
    print("Wrote \(url.path(percentEncoded: false))")
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
