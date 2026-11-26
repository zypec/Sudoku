//
//  AppSettings.swift
//  Sudoku
//

import Foundation
import Observation
import SwiftUI

/// User preferences, persisted in `UserDefaults` and shared through the environment.
@MainActor
@Observable
final class AppSettings {
    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: Self { self }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum MistakeLimit: Int, CaseIterable, Identifiable {
        case off = 0
        case three = 3
        case five = 5

        var id: Self { self }

        /// `nil` means unlimited.
        var value: Int? {
            self == .off ? nil : rawValue
        }
    }

    var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }
    var mistakeLimit: MistakeLimit {
        didSet { defaults.set(mistakeLimit.rawValue, forKey: Key.mistakeLimit) }
    }
    /// Hints guide the player: notes are checked and completed before logic. Off, a hint fills in the
    /// selected cell.
    var smartHints: Bool {
        didSet { defaults.set(smartHints, forKey: Key.smartHints) }
    }
    /// The name shared with race results.
    var playerName: String {
        didSet { defaults.set(playerName, forKey: Key.playerName) }
    }
    /// Hints the Hint button gives per game; 0 is unlimited.
    var hintLimit: Int {
        didSet { defaults.set(hintLimit, forKey: Key.hintLimit) }
    }
    /// Colors wrong digits red and shows the mistake counter.
    var showsMistakes: Bool {
        didSet { defaults.set(showsMistakes, forKey: Key.showsMistakes) }
    }
    var showsTimer: Bool {
        didSet { defaults.set(showsTimer, forKey: Key.showsTimer) }
    }
    var highlightsSameDigits: Bool {
        didSet { defaults.set(highlightsSameDigits, forKey: Key.highlightsSameDigits) }
    }
    var highlightsRelatedCells: Bool {
        didSet { defaults.set(highlightsRelatedCells, forKey: Key.highlightsRelatedCells) }
    }
    var removesNotesAutomatically: Bool {
        didSet { defaults.set(removesNotesAutomatically, forKey: Key.removesNotesAutomatically) }
    }
    var dimsCompletedDigits: Bool {
        didSet { defaults.set(dimsCompletedDigits, forKey: Key.dimsCompletedDigits) }
    }
    var showsAutoNotesButton: Bool {
        didSet { defaults.set(showsAutoNotesButton, forKey: Key.showsAutoNotesButton) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }
    /// Last speed chosen in the auto solve panel.
    var autoSolveSpeed: AutoSolveSpeed {
        didSet { defaults.set(autoSolveSpeed.rawValue, forKey: Key.autoSolveSpeed) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: Key.theme).flatMap(Theme.init(rawValue:)) ?? .system
        mistakeLimit = (defaults.object(forKey: Key.mistakeLimit) as? Int).flatMap(MistakeLimit.init(rawValue:)) ?? .three
        smartHints = defaults.object(forKey: Key.smartHints) as? Bool ?? true
        playerName = defaults.string(forKey: Key.playerName) ?? ""
        hintLimit = max(0, defaults.integer(forKey: Key.hintLimit))
        showsMistakes = defaults.object(forKey: Key.showsMistakes) as? Bool ?? true
        showsTimer = defaults.object(forKey: Key.showsTimer) as? Bool ?? true
        highlightsSameDigits = defaults.object(forKey: Key.highlightsSameDigits) as? Bool ?? true
        highlightsRelatedCells = defaults.object(forKey: Key.highlightsRelatedCells) as? Bool ?? true
        removesNotesAutomatically = defaults.object(forKey: Key.removesNotesAutomatically) as? Bool ?? true
        dimsCompletedDigits = defaults.object(forKey: Key.dimsCompletedDigits) as? Bool ?? true
        showsAutoNotesButton = defaults.object(forKey: Key.showsAutoNotesButton) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        autoSolveSpeed = (defaults.object(forKey: Key.autoSolveSpeed) as? Double).flatMap(AutoSolveSpeed.init(rawValue:)) ?? .normal
    }

    /// The mistake limit games use (new ones and the one in progress). Without visible mistakes a
    /// limit would end games without warning, so it only applies while mistakes are shown.
    var mistakeLimitSetting: Int? {
        showsMistakes ? mistakeLimit.value : nil
    }

    private enum Key {
        static let theme = "settings.theme"
        static let mistakeLimit = "settings.mistakeLimit"
        static let smartHints = "settings.smartHints"
        static let playerName = "settings.playerName"
        static let hintLimit = "settings.hintLimit"
        static let showsMistakes = "settings.showsMistakes"
        static let showsTimer = "settings.showsTimer"
        static let highlightsSameDigits = "settings.highlightsSameDigits"
        static let highlightsRelatedCells = "settings.highlightsRelatedCells"
        static let removesNotesAutomatically = "settings.removesNotesAutomatically"
        static let dimsCompletedDigits = "settings.dimsCompletedDigits"
        static let showsAutoNotesButton = "settings.showsAutoNotesButton"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let autoSolveSpeed = "settings.autoSolveSpeed"
    }
}
