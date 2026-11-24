//
//  CellView.swift
//  Sudoku
//

import SwiftUI

/// A single board cell: its digit or pencil marks, plus selection and hint highlighting.
struct CellView: View {
    enum Highlight {
        case none
        /// Shares a row, column or box with the selected cell.
        case related
        /// Holds the same digit as the selected cell.
        case sameDigit
        case selected
    }

    let cell: CellIndex
    let value: Digit
    let notes: CandidateSet
    let isGiven: Bool
    let isIncorrect: Bool
    let highlight: Highlight
    /// Notes matching this digit are emphasized.
    let highlightedDigit: Digit?
    /// Set while a hint is shown; takes precedence over selection highlighting.
    let hintStyle: HintHighlights.CellStyle?
    /// Font sizes follow the cell size so the board always fits the screen.
    let side: CGFloat
    /// Selection for assistive technologies; touch selection is handled by `BoardView`'s drag gesture.
    let action: () -> Void

    var body: some View {
        ZStack {
            background
            if value != 0 {
                Text(verbatim: "\(value)")
                    .font(.system(size: side * 0.6, weight: isGiven ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(valueStyle)
            } else if let ghostDigit = hintStyle?.ghostDigit {
                Text(verbatim: "\(ghostDigit)")
                    .font(.system(size: side * 0.6, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.green)
                    .transition(.scale.combined(with: .opacity))
            } else if !displayedNotes.isEmpty {
                notesGrid
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Row \(Geometry.row(of: cell) + 1), column \(Geometry.column(of: cell) + 1)"))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(highlight == .selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, action)
    }

    /// The player's notes plus any candidates a hint wants to show.
    private var displayedNotes: CandidateSet {
        guard let hintStyle else { return notes }
        return notes.union(hintStyle.emphasizedNotes).union(hintStyle.eliminatedNotes)
    }

    private var background: Color {
        if let hintStyle {
            if hintStyle.isIncorrect { return Color.red.opacity(0.3) }
            if hintStyle.isPattern { return Color.orange.opacity(0.3) }
            if hintStyle.isFocus { return Color.yellow.opacity(0.2) }
        }
        switch highlight {
        case .selected:
            return Color.accentColor.opacity(0.35)
        case .sameDigit:
            return Color.accentColor.opacity(0.2)
        case .related:
            return Color.accentColor.opacity(0.08)
        case .none:
            return isIncorrect ? Color.red.opacity(0.12) : Color.clear
        }
    }

    private var valueStyle: AnyShapeStyle {
        if isIncorrect {
            AnyShapeStyle(Color.red)
        } else if isGiven {
            AnyShapeStyle(.primary)
        } else {
            AnyShapeStyle(.tint)
        }
    }

    /// Pencil marks laid out like a phone keypad: 1-2-3 on top, 7-8-9 at the bottom.
    private var notesGrid: some View {
        let shown = displayedNotes
        return VStack(spacing: 0) {
            ForEach(0..<3) { row in
                HStack(spacing: 0) {
                    ForEach(1..<4) { column in
                        let digit = row * 3 + column
                        noteText(digit, isShown: shown.contains(digit))
                            .frame(width: side / 3, height: side / 3)
                    }
                }
            }
        }
    }

    private func noteText(_ digit: Digit, isShown: Bool) -> some View {
        let isEliminated = hintStyle?.eliminatedNotes.contains(digit) ?? false
        let isEmphasized = hintStyle?.emphasizedNotes.contains(digit) ?? false
        let isHighlighted = hintStyle == nil && digit == highlightedDigit

        let style: AnyShapeStyle = if isEliminated {
            AnyShapeStyle(Color.red)
        } else if isEmphasized {
            AnyShapeStyle(.primary)
        } else if isHighlighted {
            AnyShapeStyle(.tint)
        } else {
            AnyShapeStyle(.secondary)
        }

        return Text(verbatim: isShown ? "\(digit)" : " ")
            .font(.system(size: side * 0.24, weight: isEliminated || isEmphasized || isHighlighted ? .bold : .regular, design: .rounded))
            .strikethrough(isEliminated, color: .red)
            .foregroundStyle(style)
    }

    private var accessibilityValue: Text {
        if value != 0 {
            if isIncorrect {
                Text("\(value), incorrect")
            } else if isGiven {
                Text("\(value), given")
            } else {
                Text(verbatim: "\(value)")
            }
        } else if notes.isEmpty {
            Text("Empty")
        } else {
            Text("Empty, notes \(notes.map(String.init).joined(separator: " "))")
        }
    }
}
