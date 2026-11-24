//
//  BoardView.swift
//  Sudoku
//

import SwiftUI

/// The 9x9 board. Kept flat (no Liquid Glass) so digits stay legible; scales to the largest square
/// that fits the available space.
///
/// A single drag gesture handles selection, so touching a cell selects it and sliding a finger
/// across the board keeps selecting the cell under it.
struct BoardView: View {
    let model: GameModel

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cellSide = side / 9
            let hintHighlights = model.hintHighlights
            VStack(spacing: 0) {
                ForEach(0..<9) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9) { column in
                            cellView(Geometry.cell(row: row, column: column), side: cellSide, hintHighlights: hintHighlights)
                        }
                    }
                }
            }
            .animation(.snappy, value: hintHighlights)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectCell(at: value.location, cellSide: cellSide)
                    }
            )
            .background(.background)
            .overlay { GridLines() }
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary, lineWidth: 2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellView(_ cell: CellIndex, side: CGFloat, hintHighlights: HintHighlights) -> some View {
        let game = model.game
        let settings = model.settings
        // While a hint is open, selection highlighting is hidden so the hint's colors stand out.
        let isShowingHint = model.activeHint != nil
        return CellView(
            cell: cell,
            value: game.values[cell],
            notes: game.notes[cell],
            isGiven: game.isGiven(cell),
            isIncorrect: settings.showsMistakes && game.isIncorrect(cell),
            highlight: isShowingHint ? .none : highlight(for: cell),
            highlightedDigit: settings.highlightsSameDigits ? model.selectedDigit : nil,
            hintStyle: isShowingHint ? hintHighlights.style(for: cell) : nil,
            side: side
        ) {
            model.select(cell)
        }
    }

    /// Selects the cell under `location` (in board coordinates). Points outside the board are
    /// clamped to the nearest edge cell so a slightly overshooting finger still works.
    private func selectCell(at location: CGPoint, cellSide: CGFloat) {
        guard cellSide > 0 else { return }
        let row = min(max(Int(location.y / cellSide), 0), 8)
        let column = min(max(Int(location.x / cellSide), 0), 8)
        let cell = Geometry.cell(row: row, column: column)
        if cell != model.selectedCell {
            model.select(cell)
        }
    }

    private func highlight(for cell: CellIndex) -> CellView.Highlight {
        guard let selected = model.selectedCell else { return .none }
        if cell == selected {
            return .selected
        }
        let settings = model.settings
        if settings.highlightsSameDigits, let digit = model.selectedDigit, model.game.values[cell] == digit {
            return .sameDigit
        }
        return settings.highlightsRelatedCells && Geometry.sees(cell, selected) ? .related : .none
    }
}

/// Thin lines between cells and thick lines between boxes.
private struct GridLines: View {
    var body: some View {
        Canvas { context, size in
            let step = size.width / 9
            for index in 1..<9 {
                let offset = step * CGFloat(index)
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
                path.move(to: CGPoint(x: 0, y: offset))
                path.addLine(to: CGPoint(x: size.width, y: offset))

                let isBoxEdge = index % 3 == 0
                context.stroke(
                    path,
                    with: .color(isBoxEdge ? Color.primary : Color.primary.opacity(0.2)),
                    lineWidth: isBoxEdge ? 2 : 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }
}
