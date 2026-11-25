//
//  PauseView.swift
//  Sudoku
//

import SwiftUI

/// Covers the game while it's paused, so the board can't be studied with the clock stopped, and
/// sums up the game so far.
struct PauseView: View {
    let model: GameModel

    private var game: SudokuGame {
        model.game
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Paused")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(game.puzzle.difficulty.title)
                    .font(.headline)
                    .foregroundStyle(game.puzzle.difficulty.color)
            }

            VStack(spacing: 0) {
                row("Time", systemImage: "stopwatch") {
                    Text(verbatim: GameStatusView.formattedTime(game.elapsedSeconds))
                }
                Divider()
                row("Mistakes", systemImage: "heart") {
                    if let limit = game.mistakeLimit {
                        Text(verbatim: "\(game.mistakeCount)/\(limit)")
                    } else {
                        Text(verbatim: "\(game.mistakeCount)")
                    }
                }
                Divider()
                row("Hints", systemImage: "lightbulb") {
                    Text(verbatim: "\(game.hintCount)")
                }
                if let estimate = game.puzzle.estimatedSeconds {
                    Divider()
                    row("Typical Time", systemImage: "person.2") {
                        Text(Duration.seconds(estimate).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    row("Progress", systemImage: "square.grid.3x3.fill") {
                        Text("\(filledCells) of \(emptyCells) cells")
                    }
                    ProgressView(value: Double(filledCells), total: Double(max(emptyCells, 1)))
                        .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 16)
            .background(.fill.quaternary, in: .rect(cornerRadius: 20))
            .frame(maxWidth: 420)

            Spacer(minLength: 0)

            Button(action: model.resume) {
                Label("Resume", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: 420)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    /// Cells the player has filled, out of those that started empty.
    private var filledCells: Int {
        Geometry.cells.count { game.puzzle.givens[$0] == 0 && game.values[$0] != 0 }
    }

    private var emptyCells: Int {
        game.puzzle.givens.count { $0 == 0 }
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer()
            value()
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.body)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
