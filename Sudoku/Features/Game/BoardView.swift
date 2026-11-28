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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .animation(.panel, value: hintHighlights)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectCell(at: value.location, cellSide: cellSide)
                    }
            )
            .background(.background)
            .overlay { GridLines() }
            .overlay { HintLinks(links: hintHighlights.links, cellSide: cellSide) }
            .overlay(alignment: .topLeading) {
                if let target = model.autoSolveTarget {
                    AutoSolveCursor(cellSide: cellSide)
                        .offset(
                            x: CGFloat(Geometry.column(of: target)) * cellSide,
                            y: CGFloat(Geometry.row(of: target)) * cellSide
                        )
                        // Glide to each new cell; faster speeds move faster so the cursor keeps up.
                        .animation(.smooth(duration: min(0.45, model.settings.autoSolveSpeed.stepDuration * 0.3)), value: target)
                        .transition(.opacity)
                }
            }
            // Square corners: a rounded frame curved away from the straight grid lines inside it.
            .clipShape(.rect)
            .overlay {
                Rectangle()
                    .strokeBorder(Color.primary, lineWidth: 1.5)
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
        let isShowingHint = model.isShowingHintHighlights
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
        .modifier(WinWave(
            delay: reduceMotion ? 0 : waveDelay(for: cell),
            bounces: !reduceMotion,
            trigger: model.celebrationCount
        ))
    }

    /// When the win wave reaches `cell`: it spreads in rings out from the winning move.
    private func waveDelay(for cell: CellIndex) -> Double {
        let origin = model.celebrationOrigin
        let rows = Double(Geometry.row(of: cell) - Geometry.row(of: origin))
        let columns = Double(Geometry.column(of: cell) - Geometry.column(of: origin))
        return (rows * rows + columns * columns).squareRoot() * 0.05
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
                    lineWidth: isBoxEdge ? 1.5 : 0.5
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Lines between linked candidates of a hint. Strong links are solid, weak links dashed.
private struct HintLinks: View {
    let links: [HintHighlights.Link]
    let cellSide: CGFloat

    var body: some View {
        Canvas { context, _ in
            for link in links {
                let start = center(of: link.fromDigit, in: link.from)
                let end = center(of: link.toDigit, in: link.to)
                // Stop short of both candidates so the digits stay readable.
                let dx = end.x - start.x
                let dy = end.y - start.y
                let length = max(sqrt(dx * dx + dy * dy), 1)
                let inset = cellSide * 0.16 / length
                var path = Path()
                path.move(to: CGPoint(x: start.x + dx * inset, y: start.y + dy * inset))
                path.addLine(to: CGPoint(x: end.x - dx * inset, y: end.y - dy * inset))
                let style = StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    dash: link.isStrong ? [] : [cellSide * 0.1, cellSide * 0.08]
                )
                context.stroke(path, with: .color(.indigo), style: style)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Center of `digit`'s pencil-mark position inside `cell`.
    private func center(of digit: Digit, in cell: CellIndex) -> CGPoint {
        // Matches `CellView`'s notes grid: three slots across 92% of the cell, centered.
        let slot = cellSide * 0.92 / 3
        let inset = cellSide * 0.04
        let x = CGFloat(Geometry.column(of: cell)) * cellSide + inset + (CGFloat((digit - 1) % 3) + 0.5) * slot
        let y = CGFloat(Geometry.row(of: cell)) * cellSide + inset + (CGFloat((digit - 1) / 3) + 0.5) * slot
        return CGPoint(x: x, y: y)
    }
}

/// Frame that marks the cell auto solve is about to change, so the player can follow along.
private struct AutoSolveCursor: View {
    let cellSide: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cellSide * 0.12)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: cellSide * 0.12))
            .frame(width: cellSide, height: cellSide)
            .shadow(color: Color.accentColor.opacity(0.4), radius: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A cell's part of the wave that crosses the board when the puzzle is solved: it lifts and glows in
/// the accent color as the wave passes, then settles. With reduced motion it only glows, all at once.
private struct WinWave: ViewModifier {
    let delay: Double
    let bounces: Bool
    let trigger: Int

    private struct Frame {
        var scale = 1.0
        var glow = 0.0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Frame(), trigger: trigger) { view, frame in
            view
                .overlay { Color.accentColor.opacity(frame.glow).allowsHitTesting(false) }
                .scaleEffect(frame.scale)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: delay)
                SpringKeyframe(bounces ? 1.14 : 1, duration: 0.16, spring: .snappy)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.glow) {
                LinearKeyframe(0, duration: delay)
                LinearKeyframe(0.35, duration: 0.14)
                LinearKeyframe(0, duration: 0.55)
            }
        }
    }
}
