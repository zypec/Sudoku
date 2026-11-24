//
//  GameStore.swift
//  Sudoku
//

import Foundation
import OSLog

/// Saves the game in progress as a JSON file so it survives the app being closed.
/// Finished games are not kept; statistics will be recorded separately.
@MainActor
final class GameStore {
    static let shared = GameStore()

    private let url: URL
    private let logger = Logger(subsystem: "Sudoku", category: "GameStore")

    init(url: URL = URL.applicationSupportDirectory.appending(path: "CurrentGame.json")) {
        self.url = url
    }

    /// The saved game, or `nil` if there is none or it can't be read.
    func load() -> SudokuGame? {
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        do {
            let game = try JSONDecoder().decode(SudokuGame.self, from: Data(contentsOf: url))
            return game.isFinished ? nil : game
        } catch {
            logger.error("Discarding unreadable saved game: \(error.localizedDescription)")
            clear()
            return nil
        }
    }

    /// Saves an unfinished game; a finished game clears the save instead.
    func save(_ game: SudokuGame) {
        guard !game.isFinished else {
            clear()
            return
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(game).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save game: \(error.localizedDescription)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
