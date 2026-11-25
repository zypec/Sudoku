//
//  GameStore.swift
//  Sudoku
//

import Foundation
import OSLog

/// Saves the game in progress as a JSON file so it survives the app being closed.
/// Finished games are not kept; statistics are recorded separately.
///
/// Saving happens on every move, so encoding and writing run on a serial background queue and
/// never delay the next tap. Reads wait for pending writes, so they always see the latest save.
@MainActor
final class GameStore {
    static let shared = GameStore()

    private let url: URL
    private let logger = Logger(subsystem: "Sudoku", category: "GameStore")
    private let queue = DispatchQueue(label: "Sudoku.GameStore", qos: .utility)

    init(url: URL = URL.applicationSupportDirectory.appending(path: "CurrentGame.json")) {
        self.url = url
    }

    /// The saved game, or `nil` if there is none or it can't be read.
    func load() -> SudokuGame? {
        // Wait for saves still being written.
        queue.sync {}
        // `path()` percent-encodes by default ("Application%20Support"), which FileManager
        // would treat as a different, nonexistent path.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        do {
            let game = try JSONDecoder().decode(SudokuGame.self, from: Data(contentsOf: url))
            return game.isFinished ? nil : game
        } catch {
            logger.error("Discarding unreadable saved game: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Saves an unfinished game; a finished game clears the save instead.
    func save(_ game: SudokuGame) {
        guard !game.isFinished else {
            clear()
            return
        }
        let url = url
        let logger = logger
        queue.async {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(game).write(to: url, options: .atomic)
            } catch {
                logger.error("Couldn't save game: \(error.localizedDescription)")
            }
        }
    }

    func clear() {
        let url = url
        queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
