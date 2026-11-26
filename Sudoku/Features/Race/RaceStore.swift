//
//  RaceStore.swift
//  Sudoku
//

import Foundation
import Observation
import OSLog

/// A race against friends, played with codes: the same puzzle for everyone and a deadline; whoever
/// finishes first, before the deadline, wins. There is no server, so each player adds the result
/// codes the others share.
struct Race: Identifiable, Hashable, Codable, Sendable {
    /// The race code without dashes, which also tells races apart.
    let id: String
    let code: String
    let puzzle: Puzzle
    let deadline: Date
    /// Whether this player started it (and so shares its code).
    let isMine: Bool
    var joinedAt: Date
    /// This player's result, once the puzzle is solved without auto solve.
    var myResult: RaceCode.Result?
    /// Results added from other players' codes.
    var results: [RaceCode.Result] = []

    var isOver: Bool {
        Date.now >= deadline
    }

    /// Everyone's results, the first finisher first, and whether each came in time.
    func standings(myName: String) -> [(result: RaceCode.Result, isMe: Bool, inTime: Bool)] {
        var all = results.map { ($0, false) }
        if let myResult {
            all.append((myResult, true))
        }
        return all.sorted { $0.0.finishedAt < $1.0.finishedAt }
            .map { (result: $0.0, isMe: $0.1, inTime: $0.0.finishedAt <= deadline) }
    }

    /// The first result in time, if any.
    var winner: RaceCode.Result? {
        standings(myName: "").first { $0.inTime }?.result
    }
}

/// Every race this player started or joined, kept as one JSON file, and each race's game in progress
/// in a file of its own so it never touches the main saved game.
@MainActor
@Observable
final class RaceStore {
    static let shared = RaceStore()

    enum JoinError: Error, Equatable {
        case notARaceCode
        case unknownPuzzle
    }

    private(set) var races: [Race] = []

    @ObservationIgnored private let folder: URL
    @ObservationIgnored private let logger = Logger(subsystem: "Sudoku", category: "RaceStore")

    init(folder: URL = URL.applicationSupportDirectory.appending(path: "Races")) {
        self.folder = folder
        races = load()
    }

    private var listURL: URL {
        folder.appending(path: "Races.json")
    }

    /// Where a race's game in progress is saved.
    func gameStore(for race: Race) -> GameStore {
        GameStore(url: folder.appending(path: "\(race.id).json"))
    }

    // MARK: Starting and joining

    /// Time limits a race can have; there is no unlimited one, so every race ends.
    static let timeLimits: [TimeInterval] = [3600, 6 * 3600, 86400, 3 * 86400, 7 * 86400]

    /// A race on a puzzle from the bank, ending `timeLimit` from now. `nil` when the bank has no puzzle
    /// for the difficulty.
    func start(_ difficulty: Difficulty, timeLimit: TimeInterval, now: Date = .now) async -> Race? {
        let puzzle = await PuzzleSource.shared.puzzle(difficulty)
        guard puzzle.origin != nil,
              let code = RaceCode.raceCode(puzzleCode: PuzzleCode.code(for: puzzle), deadline: now.addingTimeInterval(timeLimit),
                                           salt: UInt64.random(in: 0..<1024)),
              let parsed = RaceCode.parseRace(code)
        else { return nil }
        let race = Race(id: parsed.id, code: code, puzzle: puzzle, deadline: parsed.deadline, isMine: true, joinedAt: now)
        races.insert(race, at: 0)
        persist()
        return race
    }

    /// The race a friend's code names; joining one already here returns it.
    func join(_ code: String, now: Date = .now) throws(JoinError) -> Race {
        guard let parsed = RaceCode.parseRace(code) else { throw .notARaceCode }
        if let race = races.first(where: { $0.id == parsed.id }) { return race }
        guard let puzzle = PuzzleCode.puzzle(from: parsed.puzzleCode) else { throw .unknownPuzzle }
        let formatted = stride(from: 0, to: 16, by: 4).map { String(parsed.id.dropFirst($0).prefix(4)) }.joined(separator: "-")
        let race = Race(id: parsed.id, code: formatted, puzzle: puzzle, deadline: parsed.deadline, isMine: false, joinedAt: now)
        races.insert(race, at: 0)
        persist()
        return race
    }

    func remove(_ race: Race) {
        races.removeAll { $0.id == race.id }
        gameStore(for: race).clear()
        persist()
    }

    // MARK: Results

    /// Records this player's result when the race's game is solved. A game finished by auto solve, or
    /// lost, gives none.
    func finish(_ raceID: String, game: SudokuGame, at date: Date = .now) {
        guard game.isSolved, !game.usedAutoSolve, let index = races.firstIndex(where: { $0.id == raceID }),
              races[index].myResult == nil
        else { return }
        let code = RaceCode.resultCode(raceID: raceID, name: "", finishedAt: date, seconds: game.elapsedSeconds)
        guard let result = RaceCode.parseResult(code, raceID: raceID) else { return }
        races[index].myResult = result
        persist()
    }

    /// Adds a friend's result code; `false` when it isn't a result of this race.
    @discardableResult
    func addResult(_ code: String, to raceID: String) -> Bool {
        guard let index = races.firstIndex(where: { $0.id == raceID }),
              let result = RaceCode.parseResult(code, raceID: raceID)
        else { return false }
        // The same finish shared twice, or this player's own code pasted back, counts once.
        let same: (RaceCode.Result) -> Bool = { $0.finishedAt == result.finishedAt && $0.seconds == result.seconds }
        if !races[index].results.contains(where: same), races[index].myResult.map(same) != true {
            races[index].results.append(result)
            persist()
        }
        return true
    }

    func race(_ id: String) -> Race? {
        races.first { $0.id == id }
    }

    // MARK: Files

    private func load() -> [Race] {
        guard FileManager.default.fileExists(atPath: listURL.path(percentEncoded: false)) else { return [] }
        do {
            return try JSONDecoder().decode([Race].self, from: Data(contentsOf: listURL))
        } catch {
            logger.error("Couldn't read races: \(error.localizedDescription)")
            return []
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(races).write(to: listURL, options: .atomic)
        } catch {
            logger.error("Couldn't save races: \(error.localizedDescription)")
        }
    }
}
