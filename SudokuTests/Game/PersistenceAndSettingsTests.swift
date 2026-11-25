//
//  PersistenceAndSettingsTests.swift
//  SudokuTests
//

import Foundation
import Testing
@testable import Sudoku

@MainActor
@Suite("Persistence and settings")
struct PersistenceAndSettingsTests {
    private let defaults: UserDefaults
    private let storeURL: URL

    init() throws {
        let suite = "SudokuTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        // Mirrors the real location ("Application Support"): the path contains a space.
        storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/Application Support/CurrentGame.json")
    }

    private func easyGame(mistakeLimit: Int? = 3) throws -> SudokuGame {
        let puzzle = Puzzle(
            givens: try TestPuzzles.values(TestPuzzles.easy),
            solution: try TestPuzzles.values(TestPuzzles.easySolution),
            difficulty: .easy
        )
        return SudokuGame(puzzle: puzzle, mistakeLimit: mistakeLimit)
    }

    // MARK: Settings

    @Test func settingsHaveSensibleDefaults() {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.theme == .system)
        #expect(settings.mistakeLimit == .three)
        #expect(settings.showsMistakes)
        #expect(settings.highlightsRelatedCells)
        #expect(settings.mistakeLimitSetting == 3)
    }

    @Test func settingsPersistAcrossInstances() {
        let settings = AppSettings(defaults: defaults)
        settings.theme = .dark
        settings.mistakeLimit = .five
        settings.hapticsEnabled = false

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.theme == .dark)
        #expect(reloaded.mistakeLimit == .five)
        #expect(!reloaded.hapticsEnabled)
    }

    @Test func hiddenMistakesMeanNoLimit() {
        let settings = AppSettings(defaults: defaults)
        settings.mistakeLimit = .five
        settings.showsMistakes = false
        #expect(settings.mistakeLimitSetting == nil)

        settings.showsMistakes = true
        settings.mistakeLimit = .off
        #expect(settings.mistakeLimitSetting == nil)
    }

    // MARK: Game store

    @Test func storeRoundTripsAGameInProgress() throws {
        let store = GameStore(url: storeURL)
        #expect(store.load() == nil)

        var game = try easyGame()
        game.enter(4, at: 2)
        game.toggleNote(6, at: 3)
        game.elapsedSeconds = 75
        store.save(game)

        let loaded = try #require(store.load())
        #expect(loaded.values == game.values)
        #expect(loaded.notes == game.notes)
        #expect(loaded.elapsedSeconds == 75)
        #expect(loaded.mistakeLimit == 3)
        #expect(loaded.canUndo)
    }

    @Test func finishedGamesClearTheSave() throws {
        let store = GameStore(url: storeURL)
        var game = try easyGame(mistakeLimit: 1)
        store.save(game)
        #expect(store.load() != nil)

        game.enter(1, at: 2) // wrong, and the limit is 1
        #expect(game.isLost)
        store.save(game)
        #expect(store.load() == nil)
    }

    @Test func unreadableSaveIsDiscarded() throws {
        let store = GameStore(url: storeURL)
        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storeURL)
        #expect(store.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)))
    }

    // MARK: Game model

    @Test func modelSavesAfterEveryMove() throws {
        let store = GameStore(url: storeURL)
        let model = GameModel(game: try easyGame(), settings: AppSettings(defaults: defaults), store: store)
        model.select(2)
        model.input(4)
        #expect(store.load()?.values[2] == 4)

        model.toggleNotesMode()
        model.select(3)
        model.input(6)
        #expect(store.load()?.notes[3] == [6])
    }

    @Test func newGamesTakeTheirMistakeLimitFromSettings() async {
        let settings = AppSettings(defaults: defaults)
        settings.mistakeLimit = .five
        let model = await GameModel.make(difficulty: .easy, settings: settings, store: GameStore(url: storeURL))
        #expect(model.game.mistakeLimit == 5)

        // The game in progress follows the setting.
        settings.mistakeLimit = .off
        model.applyMistakeLimitSetting()
        #expect(model.game.mistakeLimit == nil)
        settings.mistakeLimit = .three
        model.applyMistakeLimitSetting()
        #expect(model.game.mistakeLimit == 3)
    }

    /// The clock ticks outside the game (so the board isn't redrawn every second) and is written
    /// into it when saved.
    @Test func clockTicksOutsideTheGameUntilSaved() throws {
        let store = GameStore(url: storeURL)
        let model = GameModel(game: try easyGame(), settings: AppSettings(defaults: defaults), store: store)
        for _ in 0..<3 {
            model.tick()
        }
        #expect(model.elapsedSeconds == 3)
        #expect(model.game.elapsedSeconds == 0)
        model.save()
        #expect(model.game.elapsedSeconds == 3)
        #expect(store.load()?.elapsedSeconds == 3)
    }

    @Test func loweringTheLimitBelowTheMistakesLeavesOneTry() throws {
        var game = try easyGame(mistakeLimit: 5)
        game.enter(1, at: 2)  // wrong
        game.enter(2, at: 2)  // wrong
        game.enter(9, at: 2)  // wrong
        #expect(game.mistakeCount == 3)
        game.setMistakeLimit(3)
        #expect(game.mistakeLimit == 4)
        #expect(!game.isLost)
    }

    @Test func savedGamesPickUpTheCurrentLimit() throws {
        let settings = AppSettings(defaults: defaults)
        settings.mistakeLimit = .five
        let model = GameModel(game: try easyGame(mistakeLimit: 3), settings: settings)
        #expect(model.game.mistakeLimit == 5)
    }

    @Test func autoRemovingNotesFollowsTheSetting() throws {
        let settings = AppSettings(defaults: defaults)
        settings.removesNotesAutomatically = false
        var game = try easyGame()
        game.toggleNote(4, at: 3) // same row as cell 2
        let model = GameModel(game: game, settings: settings)
        model.select(2)
        model.input(4)
        #expect(model.game.notes[3].contains(4))
    }

    @Test func hintsAreUnlimitedUntilALimitIsSet() throws {
        let settings = AppSettings(defaults: defaults)
        #expect(settings.hintLimit == 0)
        let model = GameModel(game: try easyGame(), settings: settings)
        #expect(model.hintsLeft == nil)
        settings.hintLimit = 4
        #expect(AppSettings(defaults: defaults).hintLimit == 4)
    }

    @Test func theHintLimitStopsTheHintButton() throws {
        let settings = AppSettings(defaults: defaults)
        settings.hintLimit = 2
        let model = GameModel(game: try easyGame(), settings: settings)
        #expect(model.hintsLeft == 2)
        model.requestHint()
        model.requestHint()
        #expect(model.hintsLeft == 0)
        model.requestHint()
        #expect(model.game.hintCount == 2)
        // Raising the limit gives the game in progress more hints.
        settings.hintLimit = 3
        #expect(model.hintsLeft == 1)
    }
}
