//
//  TrainingPositions.swift
//  Sudoku
//

import Foundation

/// Positions for practicing a technique: moments from bank puzzles where the logical solver's
/// next step is exactly that technique and no easier one makes progress. Extracted ahead of time
/// by `Tools/PuzzleBankGenerator positions` into `TrainingPositions.json`.
struct TrainingPositions: Sendable {
    /// One position: the placed digits and every cell's candidates at that moment.
    struct Position: Codable, Hashable, Sendable {
        /// 81 characters, `.` for an empty cell.
        let values: String
        /// Candidate bitmask of every cell (`CandidateSet.rawValue`), 0 for filled cells.
        let candidates: [UInt16]

        /// The position as a board, optionally transformed so it looks new each time.
        func board(transformedBy transform: PuzzleTransform = .identity) -> Board? {
            guard let values = PuzzleBank.values(values), candidates.count == Geometry.cellCount else { return nil }
            let sets = candidates.map(CandidateSet.init(rawValue:))
            return Board(values: transform.apply(to: values), candidates: transform.apply(toCandidates: sets))
        }

        init(board: Board) {
            values = PuzzleBank.string(Geometry.cells.map(board.value(at:)))
            candidates = Geometry.cells.map { board.candidates(at: $0).rawValue }
        }
    }

    struct File: Codable, Sendable {
        var version: Int
        var positions: [String: [Position]]
    }

    static let fileVersion = 1

    private let positions: [TechniqueKind: [Position]]

    init(file: File) {
        var positions: [TechniqueKind: [Position]] = [:]
        for (key, list) in file.positions {
            if let technique = TechniqueKind(rawValue: key) {
                positions[technique] = list
            }
        }
        self.positions = positions
    }

    init(data: Data) throws {
        self.init(file: try JSONDecoder().decode(File.self, from: data))
    }

    /// The positions shipped with the app, or none if the file is missing.
    static let bundled: TrainingPositions = {
        guard let url = Bundle.main.url(forResource: "TrainingPositions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let positions = try? TrainingPositions(data: data)
        else { return TrainingPositions(file: File(version: fileVersion, positions: [:])) }
        return positions
    }()

    func positions(for technique: TechniqueKind) -> [Position] {
        positions[technique] ?? []
    }

    /// Finds practice positions in `puzzles`: for each puzzle, the moment each technique is first
    /// needed, up to `limit` per technique. Positions with few placed digits are skipped, so a
    /// practice board looks like a real game in progress.
    static func extract(from puzzles: [Puzzle], limit: Int, minimumPlaced: Int = 22) -> File {
        var found: [TechniqueKind: [Position]] = [:]
        let solver = LogicalSolver()
        for puzzle in puzzles {
            var board = Board(values: puzzle.givens)
            var seen = Set<TechniqueKind>()
            while let step = solver.nextStep(on: board) {
                let placed = board.values.count { $0 != 0 }
                if !seen.contains(step.technique), placed >= minimumPlaced, found[step.technique, default: []].count < limit {
                    seen.insert(step.technique)
                    found[step.technique, default: []].append(Position(board: board))
                }
                board.apply(step)
            }
        }
        return File(version: fileVersion, positions: Dictionary(uniqueKeysWithValues: found.map { ($0.key.rawValue, $0.value) }))
    }
}
