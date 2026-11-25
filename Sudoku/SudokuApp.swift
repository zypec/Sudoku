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

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(settings)
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(for: GameRecord.self)
    }
}
