//
//  Difficulty.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

import Foundation

enum SudokuDifficulty: String, CaseIterable, Identifiable {
    case easy = "Kolay"
    case medium = "Orta"
    case hard = "Zor"

    var id: String { rawValue }

    // Üreticide kaldırılacak hücre sayısı (yaklaşık)
    var removalCount: Int {
        switch self {
        case .easy: return 40   // 41 dolu
        case .medium: return 50 // 31 dolu
        case .hard: return 58   // 23 dolu
        }
    }
}
