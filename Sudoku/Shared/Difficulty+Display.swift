//
//  Difficulty+Display.swift
//  Sudoku
//

import SwiftUI

extension Difficulty {
    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        case .master: "Master"
        }
    }

    /// What kind of techniques the difficulty asks for.
    var summary: LocalizedStringResource {
        switch self {
        case .easy: "Only the basic techniques"
        case .medium: "Locked candidates and pairs"
        case .hard: "X-Wing and wings"
        case .expert: "Fish, coloring and rectangles"
        case .master: "Chains"
        }
    }

    var color: Color {
        switch self {
        case .easy: .green
        case .medium: .teal
        case .hard: .orange
        case .expert: .red
        case .master: .purple
        }
    }

    /// Whether puzzles of this difficulty can be generated yet.
    var isAvailable: Bool {
        PuzzleGenerator.supportedDifficulties.contains(self)
    }
}
