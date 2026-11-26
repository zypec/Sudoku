//
//  SudokuApp.swift
//  Sudoku
//
//  Created by Emre Kaya on 26.10.2024.
//

import SwiftData
import SwiftUI

@main
struct SudokuApp: App {
    @State private var settings = AppSettings()

    init() {
        AppFont.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                // Helvetica Neue for every text that doesn't set its own (rows, labels, buttons).
                .font(.app(.body))
                .environment(settings)
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(for: GameRecord.self)
    }
}
