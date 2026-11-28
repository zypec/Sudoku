//
//  PressableButtonStyle.swift
//  Sudoku
//

import SwiftUI

/// Shrinks and fades the label while pressed, for buttons that draw their own appearance.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.spring(duration: 0.16, bounce: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
