//
//  AutoSolve.swift
//  Sudoku
//

/// How fast auto solve moves from one step to the next.
enum AutoSolveSpeed: Double, CaseIterable, Identifiable {
    case half = 0.5
    case normal = 1
    case double = 2
    case quadruple = 4

    var id: Self { self }

    /// Seconds a step stays on screen before it is applied.
    var stepDuration: Double {
        1.6 / rawValue
    }

    /// "0.5x", "1x", "2x", "4x". The same in every language.
    var label: String {
        self == .half ? "0.5x" : "\(Int(rawValue))x"
    }
}

/// A running auto solve, shown by `AutoSolvePanel`.
struct AutoSolveState: Equatable {
    var isPaused = false
    /// The step on screen, applied once its time is up.
    var hint: Hint?
    /// The step's result page: its text and the highlights shown on the board.
    var page: HintPage?
    var appliedSteps = 0
    /// The next step needs a technique the solver doesn't know, so auto solve can't continue.
    var isStuck = false
}
