//
//  PlayButton.swift
//  Sudoku
//
//  Created by Emre Kaya on 2.11.2024.
//

import SwiftUI

struct PlayButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? Color.blue : Color.red)
            .foregroundColor(.white)
            .font(.headline)
            .clipShape(Capsule())
    }
}
