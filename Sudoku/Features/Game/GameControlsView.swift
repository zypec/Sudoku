//
//  GameControlsView.swift
//  Sudoku
//

import SwiftUI

/// Undo, redo, erase, notes mode, auto notes and hint as round icon buttons with a caption.
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

            if model.settings.showsAutoNotesButton {
                ControlButton(title: "Auto Notes", systemImage: "square.grid.3x3") {
                    model.fillNotes()
                }
            }

            ControlButton(title: "Hint", systemImage: "lightbulb") {
                model.requestHint()
            }
        }
        .disabled(model.game.isFinished)
    }
}

private struct ControlButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isOn = false
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
    }
}
