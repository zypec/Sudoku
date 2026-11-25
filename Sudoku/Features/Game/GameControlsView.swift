//
//  GameControlsView.swift
//  Sudoku
//

import SwiftUI

/// Undo, redo, erase, notes mode and hint as round icon buttons with a caption.
/// Auto Notes overwrites every pencil mark, so it lives in the toolbar menu instead, away from
/// the keys the player taps constantly.
struct GameControlsView: View {
    let model: GameModel

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ControlButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                model.undo()
            }
            .disabled(!model.game.canUndo)

            ControlButton(title: "Redo", systemImage: "arrow.uturn.forward") {
                model.redo()
            }
            .disabled(!model.game.canRedo)

            ControlButton(title: "Erase", systemImage: "eraser") {
                model.eraseSelectedCell()
            }

            ControlButton(title: "Notes", systemImage: "pencil", isOn: model.isNotesMode) {
                model.toggleNotesMode()
            }

            ControlButton(title: "Hint", systemImage: "lightbulb", badge: model.hintsLeft) {
                model.requestHint()
            }
            .disabled(model.hintsLeft == 0)
        }
        .disabled(model.game.isFinished)
    }
}

private struct ControlButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isOn = false
    /// A count shown on the button's corner, such as the hints left.
    var badge: Int? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                    .frame(width: 48, height: 48)
                    .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary), in: .circle)
                    .overlay(alignment: .topTrailing) {
                        if let badge {
                            Text(badge, format: .number)
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.accentColor, in: .capsule)
                                .offset(x: 4, y: -2)
                                .contentTransition(.numericText())
                        }
                    }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .opacity(isEnabled ? 1 : 0.35)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .animation(.snappy, value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityValue(badge.map { Text("Hints left: \($0)") } ?? Text(verbatim: ""))
    }
}
