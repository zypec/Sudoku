//
//  NumberPadView.swift
//  Sudoku
//

import SwiftUI

/// Digit keys 1 to 9 drawn as large bare numerals. Each key shows how many of that digit are still
/// missing; completed digits fade out. In notes mode each digit shrinks into the corner where it
/// appears as a pencil mark (1 top-left through 9 bottom-right), so the mode is visible at a glance.
struct NumberPadView: View {
    let model: GameModel
    /// 9 for a single row under the board, 3 for a keypad next to the board on wide screens.
    var columns = 9

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 12) {
            ForEach(1..<10) { digit in
                key(for: digit)
            }
        }
    }

    private func key(for digit: Digit) -> some View {
        let remaining = model.game.remainingCount(of: digit)
        let isCompleted = model.settings.dimsCompletedDigits && remaining == 0
        return Button {
            model.input(digit)
        } label: {
            VStack(spacing: 2) {
                digitLabel(digit)
                    .frame(height: 44)
                Text(verbatim: "\(remaining)")
                    .font(.app(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .opacity(isCompleted ? 0.15 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(isCompleted || model.game.isFinished)
        .animation(.snappy, value: model.isNotesMode)
        .accessibilityLabel(Text(verbatim: "\(digit)"))
        .accessibilityValue(Text("\(remaining) remaining"))
    }

    @ViewBuilder
    private func digitLabel(_ digit: Digit) -> some View {
        if model.isNotesMode {
            // A miniature cell with the digit where it would sit as a pencil mark.
            let horizontal: HorizontalAlignment = [.leading, .center, .trailing][(digit - 1) % 3]
            let vertical: VerticalAlignment = [.top, .center, .bottom][(digit - 1) / 3]
            Text(verbatim: "\(digit)")
                .font(.app(.footnote, weight: .bold))
                .foregroundStyle(.tint)
                .padding(4)
                .frame(width: 36, height: 36, alignment: Alignment(horizontal: horizontal, vertical: vertical))
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.tint.opacity(0.5), lineWidth: 1)
                }
        } else {
            Text(verbatim: "\(digit)")
                .font(.app(.largeTitle, weight: .regular))
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
